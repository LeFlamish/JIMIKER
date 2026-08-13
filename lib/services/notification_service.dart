import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jimiker/features/home/menu/chat/services/open_direct_chat.dart';

/// 알림을 눌렀을 때 화면을 이동하려면 위젯 밖에서도 쓸 수 있는 네비게이터가 필요하다.
/// MaterialApp에 이 키를 물려준다.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

/// 앱이 완전히 꺼져 있을 때 오는 메시지를 처리하는 진입점.
///
/// 최상위 함수여야 하고, 별도 isolate에서 도는 탓에 화면을 건드릴 수 없다.
/// 시스템이 알림 자체는 알아서 띄우므로 여기서는 아무것도 하지 않는다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  debugPrint('background message: ${message.messageId}');
}

/// 푸시 알림 수신을 담당한다.
///
/// 서버(Cloud Functions)는 이미 알림을 보내고 있지만, 앱 쪽에 이 처리가 없으면
///  - iOS는 권한을 물어보지 않아 알림이 아예 오지 않고
///  - 앱이 켜져 있을 때는 조용히 지나가고
///  - 알림을 눌러도 해당 채팅방으로 가지 않는다.
class NotificationService {
  const NotificationService._();

  /// 서버(functions/src/index.ts)가 지정하는 채널 ID와 반드시 같아야 한다.
  /// 안드로이드는 없는 채널로 오면 중요도 설정이 먹지 않는다.
  static const String _channelId = 'high_importance_channel';

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
        _channelId,
        '채팅 알림',
        description: '새 메시지와 예약 소식을 알려줍니다.',
        importance: Importance.high,
      );

  /// main()에서 Firebase 초기화 직후 한 번 부른다.
  static Future<void> init() async {
    await _requestPermission();
    await _setUpLocalNotifications();

    // 앱이 켜져 있는 동안에는 시스템이 알림을 띄우지 않으므로 직접 띄운다.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // 백그라운드에 있던 앱을 알림으로 깨운 경우
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 앱이 꺼져 있다가 알림으로 시작된 경우
    final initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      // 첫 화면이 올라온 뒤에 이동해야 네비게이터가 준비돼 있다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTap(initialMessage);
      });
    }
  }

  static Future<void> _requestPermission() async {
    // iOS와 안드로이드 13 이상은 사용자가 허용해야 알림이 온다.
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS에서 앱이 켜져 있을 때도 배너를 띄우려면 필요하다.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> _setUpLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // 권한은 위에서 firebase_messaging이 이미 받는다.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _openRoom(_roomIdFromPayload(payload));
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> _showForegroundNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    if (notification == null) return;

    // 지금 보고 있는 채팅방의 메시지까지 알림으로 띄우면 성가시다.
    if (_isViewingRoom(message.data['roomId']?.toString())) return;

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleTap(RemoteMessage message) {
    _openRoom(message.data['roomId']?.toString());
  }

  static String? _roomIdFromPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return data['roomId']?.toString();
    } catch (error) {
      debugPrint('Invalid notification payload: $payload');
      return null;
    }
  }

  static Future<void> _openRoom(String? roomId) async {
    if (roomId == null || roomId.isEmpty) return;

    final navigator = appNavigatorKey.currentState;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (navigator == null || uid == null) return;

    try {
      await openChatRoomById(
        navigator: navigator,
        firestore: FirebaseFirestore.instance,
        uid: uid,
        roomId: roomId,
      );
    } catch (error) {
      debugPrint('Failed to open room $roomId from notification: $error');
    }
  }

  /// 이미 그 채팅방을 보고 있는지. 라우트 이름 대신 현재 화면을 직접 확인한다.
  static bool _isViewingRoom(String? roomId) {
    if (roomId == null) return false;
    return currentChatRoomId == roomId;
  }

  /// 지금 열려 있는 채팅방 id. ChatRoomScreen이 들어오고 나갈 때 갱신한다.
  static String? currentChatRoomId;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:jimiker/features/home/menu/chat/screens/chat_room_screen.dart';
import 'package:jimiker/features/home/menu/chat/screens/chat_screen.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';

/// 방 id만 알 때 그 채팅방을 연다. (알림을 눌러 들어오는 경우)
///
/// 방 이름은 문서에서 상대를 찾아 채운다. 상대를 못 찾으면 방 이름만 쓰고,
/// 그것도 없으면 '지미커'로 둔다.
Future<void> openChatRoomById({
  required NavigatorState navigator,
  required FirebaseFirestore firestore,
  required String uid,
  required String roomId,
}) async {
  final roomSnapshot = await firestore
      .collection('chat_rooms')
      .doc(roomId)
      .get();
  if (!roomSnapshot.exists) return;

  final data = roomSnapshot.data() ?? {};
  final participantUids =
      (data['participantUids'] as List<dynamic>?)?.cast<String>() ??
      const [];
  final opponentUid = participantUids.firstWhere(
    (participant) => participant != uid && participant != 'system',
    orElse: () => '',
  );

  var roomName = data['roomName']?.toString().trim() ?? '';
  if (opponentUid.isNotEmpty) {
    final opponent = await firestore
        .collection('users')
        .doc(opponentUid)
        .get();
    final nickName = opponent.data()?['nickName']?.toString().trim();
    if (nickName != null && nickName.isNotEmpty) roomName = nickName;
  }

  navigator.push(
    MaterialPageRoute(
      builder: (_) => ChatRoomScreen(
        roomId: roomId,
        roomName: roomName.isEmpty ? '지미커' : roomName,
        opponentUid: opponentUid.isEmpty ? null : opponentUid,
      ),
    ),
  );
}

/// 상대와의 1:1 채팅방을 연다.
///
/// 이미 상대와의 방이 있으면 그 방을 그대로 열고, 없으면 새 방 id만 만들어 들어간다.
/// 이 시점에는 Firestore에 아무것도 쓰지 않기 때문에, 아무 말도 안 하고 나오면
/// 방은 저장되지 않는다. (첫 메시지를 보내는 순간 방이 만들어진다.)
///
/// 화면이 사라진 뒤에도 이동할 수 있도록 [BuildContext] 대신
/// [NavigatorState]를 미리 받아둔다.
/// [initialMessage]를 넘기면 입력창에 초안으로 채워둔다. (자동 발송은 하지 않는다)
Future<void> openDirectChatRoom({
  required NavigatorState navigator,
  required FirebaseFirestore firestore,
  required String uid,
  required String opponentUid,
  String? initialMessage,
}) async {
  final chatService = ChatService(firestore);

  final roomId = await chatService.resolveDirectRoomId(
    uid: uid,
    opponentUid: opponentUid,
  );

  final opponentSnapshot = await firestore
      .collection('users')
      .doc(opponentUid)
      .get();
  final opponentName = opponentSnapshot
      .data()?['nickName']
      ?.toString()
      .trim();
  final roomName = (opponentName == null || opponentName.isEmpty)
      ? '지미커'
      : opponentName;

  // 뒤로 가면 채팅 목록이 보이도록 목록 → 방 순서로 쌓는다.
  navigator.push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  navigator.push(
    MaterialPageRoute(
      builder: (_) => ChatRoomScreen(
        roomId: roomId,
        roomName: roomName,
        opponentUid: opponentUid,
        initialMessage: initialMessage,
      ),
    ),
  );
}

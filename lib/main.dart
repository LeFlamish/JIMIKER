import 'package:flutter/material.dart';
import 'services/firebase_options.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 앱이 꺼져 있을 때 오는 메시지 처리기는 runApp 전에 등록해야 한다.
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );
  await NotificationService.init();

  runApp(const ProviderScope(child: JimikerApp()));
}

class JimikerApp extends StatelessWidget {
  const JimikerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 알림을 눌렀을 때 위젯 밖에서 화면을 이동하기 위해 필요하다.
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: '지미커',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E5BFF),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: HomeScreen(),
    );
  }
}

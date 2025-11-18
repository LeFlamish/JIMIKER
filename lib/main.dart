import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jimiker/features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  runApp(const JimikerApp());
}

class JimikerApp extends StatelessWidget {
  const JimikerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '지미커',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E5BFF),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7), // 배경도 맞춰주면 깔끔
      ),
      home: const HomeScreen(),
    );
  }
}

// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'widgets/banners/home_banner_carousel.dart';
import 'widgets/home_action_grid.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              HomeBannerCarousel(),
              SizedBox(height: 24),
              // 섹션 타이틀
              Text(
                '무엇을 하시겠어요?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),

              HomeActionGrid(), // ✅ 버튼 여러 개 들어가는 그리드
              SizedBox(height: 24),
              // TODO: 아래에 카테고리/그리드 영역 이어서 추가
            ],
          ),
        ),
      ),
    );
  }
}

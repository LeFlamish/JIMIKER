// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'widgets/banners/home_banner_carousel.dart';
import 'widgets/home_action_grid.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeBannerCarousel(),
              SizedBox(height: 24),
              Text(
                '무엇을 하시겠어요?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              HomeActionGrid(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

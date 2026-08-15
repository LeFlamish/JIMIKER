// lib/features/home/widgets/home_banner.dart
import 'package:flutter/material.dart';

/// 홈 상단 배너 한 장. 캐러셀이 문구만 바꿔서 여러 장 돌린다.
class HomeBanner extends StatelessWidget {
  const HomeBanner({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  final String badge;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B7AF5), Color(0xFF7AE8D6)],
        ),
      ),
      child: Stack(
        children: [
          // 텍스트 영역
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JIMIKER',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // 오른쪽 세로 바(그래프처럼 보이는 장식)
          Positioned(
            top: 62,
            right: 26,
            child: Row(
              children: List.generate(4, (index) {
                return Container(
                  width: 16,
                  height: 70,
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white.withValues(
                      alpha: 0.9 - index * 0.15,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

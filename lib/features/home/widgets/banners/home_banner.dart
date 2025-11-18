// lib/features/home/widgets/home_banner.dart
import 'package:flutter/material.dart';

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5E5BFF),
            Color(0xFF7AE8D6),
          ],
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
                Row(
                  children: const [
                    Text(
                      'JIMIKER',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.notifications_none, color: Colors.white),
                    SizedBox(width: 12),
                    Icon(Icons.lock_outline, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '지미커 사용 방법 확인',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '지미커 사용자 가이드',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '창고를 공유하고 싶은 공간 소유자도,\n'
                      '창고를 사용하고 싶은 공간 수요자도.',
                  style: TextStyle(
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
                    color: Colors.white.withOpacity(0.9 - index * 0.15),
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

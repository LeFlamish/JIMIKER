import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../service/auth_providers.dart';

class MyInformationScreen extends ConsumerWidget {
  const MyInformationScreen({super.key});

  // 브랜드 컬러 정의 (스크린샷 기반 추정)
  final Color primaryPurple = const Color(0xFF6A65F6); // 메인 보라색
  final Color gradientStart = const Color(0xFF6A65F6);
  final Color gradientEnd = const Color(0xFF82D8FF); // 메인 하늘색
  final Color backgroundColor = const Color(0xFFF5F5F5); // 배경 연회색
  final Color textDark = const Color(0xFF222222);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          '내 정보',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            // 뒤로가기 기능 (필요 시 구현)
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // 1. 상단 프로필 카드 (그라데이션 적용)
            _buildProfileCard(
              name: me != null ? me.nickName : '',
              email: me != null ? me.email : '',
              photoURL: me != null ? me.photoURL : '',
            ),

            const SizedBox(height: 24),

            // 2. 계정 설정 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "계정 관리",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildMenuTile(Icons.person_outline, "프로필 수정"),
                  _buildMenuTile(Icons.lock_outline, "비밀번호 변경"),
                  _buildMenuTile(Icons.payment, "결제 수단 관리"),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. 앱 설정 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "앱 설정",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildMenuTile(Icons.notifications_none, "알림 설정"),
                  _buildMenuTile(
                    Icons.headset_mic_outlined,
                    "고객센터 / 문의하기",
                  ),
                  _buildMenuTile(Icons.info_outline, "약관 및 정책"),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. 하단 로그아웃 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextButton(
                onPressed: () {
                  // 로그아웃 로직
                  authController.signOut(context);
                },
                child: const Text(
                  "로그아웃",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 위젯: 프로필 카드
  Widget _buildProfileCard({
    required String name,
    required String email,
    required String photoURL,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientStart.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 이미지 (원형)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 35,
            ),
          ),
          const SizedBox(width: 16),
          // 이름 및 이메일
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          // 수정 아이콘
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.edit,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // 위젯: 메뉴 리스트 아이템 (카드 형태)
  Widget _buildMenuTile(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // 스크린샷의 둥근 모서리 반영
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF), // 연한 보라색 배경
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryPurple, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          // 메뉴 클릭 이벤트
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authController = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          // 1. 배경 그라데이션 (제공된 이미지의 톤 앤 매너 적용)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5E60CE), // 상단: 부드러운 퍼플 블루
                  Color(0xFF48CAE4), // 하단: 밝은 시안(민트)
                ],
              ),
            ),
          ),

          // 2. 메인 컨텐츠
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 앱 로고 (텍스트 형태)
                  const Text(
                    'JIMIKER',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '당신의 공간을 스마트하게 관리하세요',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // 3. 로그인 카드 영역
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 30,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        24,
                      ), // 둥근 모서리 강조
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '서비스 이용을 위해 로그인해주세요.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // 4. 구글 로그인 버튼
                        _googleLoginButton(
                          onPressed: () async {
                            final loginResult = await authController
                                .signInWithGoogle();
                            if (loginResult) {
                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 구글 로그인 버튼 위젯
  Widget _googleLoginButton({required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Image.asset(
                'assets/images/Google_G_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Google 계정으로 계속하기',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

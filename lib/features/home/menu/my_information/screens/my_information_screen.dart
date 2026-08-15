import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/data/services/deletion_service.dart';
import 'package:jimiker/features/auth/terms/terms_document_screen.dart';
import 'package:jimiker/features/auth/terms/terms_documents.dart';
import 'package:jimiker/features/home/menu/my_information/profile_edit/screens/profile_edit_screen.dart';
import 'package:jimiker/services/auth_providers.dart';

class MyInformationScreen extends ConsumerWidget {
  const MyInformationScreen({super.key});

  // 브랜드 컬러
  final Color primaryPurple = const Color(0xFF6B7AF5);
  final Color gradientStart = const Color(0xFF6B7AF5);
  final Color gradientEnd = const Color(0xFF82D8FF); // 메인 하늘색
  final Color backgroundColor = const Color(0xFFF5F6FA);
  final Color textDark = const Color(0xFF222222);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
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
                    _buildMenuTile(
                      Icons.person_outline,
                      "프로필 수정",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ProfileEditScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      Icons.person_remove_outlined,
                      "회원 탈퇴",
                      onTap: () => _confirmWithdraw(context, ref),
                    ),
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
                    _buildMenuTile(
                      Icons.notifications_none,
                      "알림 설정",
                      onTap: () => _showNotificationGuide(context),
                    ),
                    _buildMenuTile(
                      Icons.headset_mic_outlined,
                      "고객센터 / 문의하기",
                      onTap: () => _showContactDialog(context),
                    ),
                    _buildMenuTile(
                      Icons.info_outline,
                      "약관 및 정책",
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TermsListScreen(),
                        ),
                      ),
                    ),
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
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
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
            color: gradientStart.withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A85FF), Color(0xFF8F94FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipOval(
                child: photoURL == ""
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 35,
                      )
                    : CachedImage(
                        imageUrl: photoURL,
                        width: 60,
                        height: 60,
                        errorWidget: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
              ),
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
        ],
      ),
    );
  }

  /// 알림은 앱 안이 아니라 기기 설정에서 켜고 끈다. 가는 길을 알려준다.
  void _showNotificationGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('알림 설정'),
        content: const Text(
          '예약 승인·채팅 같은 알림은 기기 설정에서 켜고 끌 수 있어요.\n\n'
          '설정 → 애플리케이션 → 지미커 → 알림',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 문의 창구. 메일 주소를 바로 복사할 수 있게 한다.
  void _showContactDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('고객센터 / 문의하기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이용 중 불편한 점이나 궁금한 점은\n아래 메일로 보내주세요.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                contactEmail,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '닫기',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: contactEmail),
              );
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('메일 주소를 복사했어요.')),
              );
            },
            child: const Text(
              '주소 복사',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 위젯: 메뉴 리스트 아이템 (카드 형태)
  Widget _buildMenuTile(
    IconData icon,
    String title, {
    void Function()? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // 스크린샷의 둥근 모서리 반영
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
        onTap: onTap,
      ),
    );
  }

  /// 회원 탈퇴. 되돌릴 수 없으므로 무엇이 지워지고 무엇이 남는지 먼저 알려준다.
  Future<void> _confirmWithdraw(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('회원 탈퇴'),
        content: const Text(
          '탈퇴하면 프로필 정보가 지워지고, 등록한 창고는 '
          '지도와 목록에서 내려가요.\n'
          '이미 끝난 거래 기록은 상대방에게도 필요해서 남지만, '
          '내 이름은 "탈퇴한 사용자"로 바뀝니다.\n\n'
          '되돌릴 수 없어요. 정말 탈퇴할까요?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '닫기',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              '탈퇴하기',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(deletionServiceProvider).deleteAccount();

      navigator.pop(); // 로딩 닫기
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('탈퇴가 완료되었어요.')),
      );
    } on DeletionBlocked catch (error) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('탈퇴 처리에 실패했어요.')),
      );
    }
  }
}

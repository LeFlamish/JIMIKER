// my_information_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyInformationScreen extends StatelessWidget {
  const MyInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 홈 화면 느낌(연한 배경 + 카드형 타일)에 맞춘 기본 톤
    const bg = Color(0xFFF6F7FB);
    const card = Color(0xFFF7F2FF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 그라데이션 헤더(홈 배너 톤 맞춤)
              _GradientHeaderCard(
                title: '내 정보',
                subtitle: '프로필, 결제/이용, 알림 설정을 관리하세요.',
                rightTopIcon: CupertinoIcons.bell,
                rightTopIcon2: CupertinoIcons.lock,
                onTapBell: () {
                  // TODO: 알림 설정/알림함 화면으로 이동
                },
                onTapLock: () {
                  // TODO: 보안 설정 화면으로 이동
                },
              ),

              const SizedBox(height: 18),

              Text(
                '계정',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // 프로필 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 14,
                      offset: Offset(0, 8),
                      color: Color(0x14000000),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFE7E0FF),
                      child: Icon(
                        CupertinoIcons.person_fill,
                        color: Color(0xFF4B4B8C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '정지욱',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _Pill(
                                text: '일반',
                                background: const Color(0xFFE7E0FF),
                                foreground: const Color(0xFF4B4B8C),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'jimik***@gmail.com',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _InfoChip(
                                icon: CupertinoIcons.phone,
                                label: '010-****-****',
                              ),
                              _InfoChip(
                                icon: CupertinoIcons.location,
                                label: '대구 수성구',
                              ),
                              _InfoChip(
                                icon: CupertinoIcons.clock,
                                label: '최근 로그인: 오늘',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        // TODO: 프로필 편집 화면으로 이동
                      },
                      icon: const Icon(
                        CupertinoIcons.pencil,
                        color: Color(0xFF4B4B8C),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Text(
                '무엇을 하시겠어요?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 14),

              // 홈 타일과 같은 느낌의 2열 그리드 액션
              LayoutBuilder(
                builder: (context, c) {
                  final width = c.maxWidth;
                  final itemW = (width - 14) / 2;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: itemW,
                        child: _ActionTile(
                          background: card,
                          icon: CupertinoIcons.person_crop_circle,
                          title: '프로필 편집',
                          subtitle: '바로가기',
                          onTap: () {
                            // TODO: 프로필 편집
                          },
                        ),
                      ),
                      SizedBox(
                        width: itemW,
                        child: _ActionTile(
                          background: card,
                          icon: CupertinoIcons.bell,
                          title: '알림 설정',
                          subtitle: '바로가기',
                          onTap: () {
                            // TODO: 알림 설정
                          },
                        ),
                      ),
                      SizedBox(
                        width: itemW,
                        child: _ActionTile(
                          background: card,
                          icon: CupertinoIcons.creditcard,
                          title: '결제 수단',
                          subtitle: '바로가기',
                          onTap: () {
                            // TODO: 결제 수단 관리
                          },
                        ),
                      ),
                      SizedBox(
                        width: itemW,
                        child: _ActionTile(
                          background: card,
                          icon: CupertinoIcons.doc_text,
                          title: '약관/정책',
                          subtitle: '바로가기',
                          onTap: () {
                            // TODO: 약관/정책
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 22),

              // 리스트 섹션(설정/지원 등)
              Text(
                '설정',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              _MenuCard(
                background: card,
                children: [
                  _MenuRow(
                    icon: CupertinoIcons.lock_shield,
                    title: '보안',
                    subtitle: '비밀번호, 2단계 인증',
                    onTap: () {
                      // TODO: 보안 설정 화면
                    },
                  ),
                  _DividerLine(),
                  _MenuRow(
                    icon: CupertinoIcons.location_solid,
                    title: '주소 관리',
                    subtitle: '기본 주소, 배송지',
                    onTap: () {
                      // TODO: 주소 관리 화면
                    },
                  ),
                  _DividerLine(),
                  _MenuRow(
                    icon: CupertinoIcons.chat_bubble_2,
                    title: '고객센터',
                    subtitle: '문의하기, FAQ',
                    onTap: () {
                      // TODO: 고객센터
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _MenuCard(
                background: card,
                children: [
                  _MenuRow(
                    icon: CupertinoIcons.square_arrow_right,
                    title: '로그아웃',
                    subtitle: '계정에서 로그아웃합니다',
                    isDestructive: true,
                    onTap: () => _showLogoutSheet(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF6F7FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '로그아웃할까요?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '언제든 다시 로그인할 수 있어요.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryButton(
                      label: '취소',
                      isFilled: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PrimaryButton(
                      label: '로그아웃',
                      isFilled: true,
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: 실제 로그아웃 로직 연결 (FirebaseAuth signOut 등)
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================
// UI Components
// ============================

class _GradientHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData rightTopIcon;
  final IconData rightTopIcon2;
  final VoidCallback onTapBell;
  final VoidCallback onTapLock;

  const _GradientHeaderCard({
    required this.title,
    required this.subtitle,
    required this.rightTopIcon,
    required this.rightTopIcon2,
    required this.onTapBell,
    required this.onTapLock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5A6CFF),
            Color(0xFF57D9D7),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 2,
            child: Row(
              children: [
                IconButton(
                  onPressed: onTapBell,
                  icon: Icon(rightTopIcon, color: Colors.white),
                ),
                IconButton(
                  onPressed: onTapLock,
                  icon: Icon(rightTopIcon2, color: Colors.white),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JIMIKER',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final Color background;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.background,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 118,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                blurRadius: 14,
                offset: Offset(0, 8),
                color: Color(0x12000000),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF4B4B8C), size: 26),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final Color background;
  final List<Widget> children;

  const _MenuCard({
    required this.background,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDestructive ? const Color(0xFFD13B3B) : Colors.black87;
    final iconColor =
    isDestructive ? const Color(0xFFD13B3B) : const Color(0xFF4B4B8C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: Colors.black38,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Divider(height: 1, thickness: 1, color: Color(0x14000000)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isFilled;
  final bool isDestructive;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.isFilled,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isDestructive ? const Color(0xFFD13B3B) : const Color(0xFF5A6CFF);
    final borderColor = isDestructive ? const Color(0xFFD13B3B) : const Color(0xFF5A6CFF);

    return SizedBox(
      height: 46,
      child: Material(
        color: isFilled ? fillColor : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isFilled ? Colors.white : borderColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

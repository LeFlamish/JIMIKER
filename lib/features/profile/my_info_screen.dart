// lib/features/profile/my_info_screen.dart
import 'package:flutter/material.dart';

class MyInfoScreen extends StatelessWidget {
  const MyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 상단 프로필 영역
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    '지', // TODO: 유저 이니셜/프로필 이미지로 교체
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '사용자 이름', // TODO: 실제 이름
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'email@example.com', // TODO: 실제 이메일
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 기본 정보 카드
          _SectionCard(
            title: '기본 정보',
            children: [
              _InfoTile(
                label: '이름',
                value: '사용자 이름', // TODO
                onTap: () {
                  // TODO: 이름 수정 화면/다이얼로그
                },
              ),
              _InfoTile(
                label: '전화번호',
                value: '010-0000-0000', // TODO
                onTap: () {
                  // TODO: 전화번호 수정
                },
              ),
              _InfoTile(
                label: '이메일',
                value: 'email@example.com', // TODO
                onTap: () {
                  // TODO: 이메일 수정
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 앱 설정 카드
          _SectionCard(
            title: '앱 설정',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('알림 받기'),
                value: true, // TODO: 실제 값 연동
                onChanged: (value) {
                  // TODO: 알림 설정 변경
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('약관 및 개인정보 처리방침'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 약관 화면으로 이동
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 계정 관리
          _SectionCard(
            title: '계정',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '로그아웃',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  // TODO: 로그아웃 처리
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                offset: const Offset(0, 3),
                color: Colors.black.withValues(alpha: 0.03),
              ),
            ],
          ),
          child: Column(
            children:
                children.expand((w) => [w, const Divider(height: 1)]).toList()
                  ..removeLast(), // 마지막 Divider 제거
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: onTap != null
          ? const Icon(Icons.edit_outlined, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

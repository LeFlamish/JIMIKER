// lib/features/home/widgets/home_action_grid.dart
import 'package:flutter/material.dart';
import 'package:jimiker/features/profile/my_info_screen.dart';

class HomeActionGrid extends StatelessWidget {
  const HomeActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      // 1행
      _HomeActionItem(
        icon: Icons.search,
        label: '창고 찾기',
        onTap: () {
          // TODO: 창고 검색 화면으로 이동
        },
      ),
      _HomeActionItem(
        icon: Icons.add_business_outlined,
        label: '창고 등록',
        onTap: () {
          // TODO: 창고 등록 플로우로 이동
        },
      ),

      // 2행
      _HomeActionItem(
        icon: Icons.store_mall_directory_outlined,
        label: '내 창고 관리',
        onTap: () {
          // TODO: 내 창고 관리 화면으로 이동
        },
      ),
      _HomeActionItem(
        icon: Icons.inventory_2_outlined,
        label: '이용 중인 창고',
        onTap: () {
          // TODO: 이용 중인 창고 화면으로 이동
        },
      ),

      // 3행
      _HomeActionItem(
        icon: Icons.receipt_long_outlined,
        label: '예약 내역',
        onTap: () {
          // TODO: 예약 내역 화면으로 이동
        },
      ),
      _HomeActionItem(
        icon: Icons.history,
        label: '이용 내역',
        onTap: () {
          // TODO: 이용 내역 화면으로 이동
        },
      ),

      // 4행
      _HomeActionItem(
        icon: Icons.chat_bubble_outline,
        label: '채팅',
        onTap: () {
          // TODO: 채팅 화면으로 이동
        },
      ),
      _HomeActionItem(
        icon: Icons.person_outline,
        label: '내 정보',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyInfoScreen()));
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        return _HomeActionCard(item: item);
      },
    );
  }
}

class _HomeActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _HomeActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _HomeActionCard extends StatelessWidget {
  final _HomeActionItem item;

  const _HomeActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                offset: const Offset(0, 3),
                color: Colors.black.withValues(alpha: 0.03),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.icon, size: 24, color: theme.colorScheme.primary),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '바로가기',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

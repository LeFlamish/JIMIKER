import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/home/menu/chat/screens/chat_screen.dart';
import 'package:jimiker/services/auth_providers.dart';
import 'package:jimiker/features/home/menu/my_information/my_information_screen.dart';
import '../menu/find_storage/find_storage_screen.dart';
import '../menu/register_storage/screens/register_storage_screen.dart';

class HomeActionGrid extends ConsumerWidget {
  const HomeActionGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authController = ref.read(authControllerProvider.notifier);

    final actions = [
      // 1행
      _HomeActionItem(
        icon: Icons.search,
        label: '창고 찾기',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Research()),
          );
        },
      ),
      _HomeActionItem(
        icon: Icons.add_business_outlined,
        label: '창고 등록',
        onTap: () async {
          final bool check = await authController.checkSignIn(
            context,
          );

          if (!context.mounted) return;

          if (check) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegisterStorageScreen(),
              ),
            );
          }
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
        onTap: () async {
          final bool check = await authController.checkSignIn(
            context,
          );

          if (!context.mounted) return;

          if (check) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatScreen(),
              ),
            );
          }
        },
      ),
      _HomeActionItem(
        icon: Icons.person_outline,
        label: '내 정보',
        onTap: () async {
          final bool check = await authController.checkSignIn(
            context,
          );

          if (!context.mounted) return;

          if (check) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MyInformationScreen(),
              ),
            );
          }
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
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
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
              Icon(
                item.icon,
                size: 24,
                color: theme.colorScheme.primary,
              ),
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
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
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

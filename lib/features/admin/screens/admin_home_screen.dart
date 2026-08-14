import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/admin/screens/admin_logs_screen.dart';
import 'package:jimiker/features/admin/screens/admin_trades_screen.dart';
import 'package:jimiker/features/admin/screens/admin_users_screen.dart';
import 'package:jimiker/features/admin/screens/storage_review_screen.dart';
import 'package:jimiker/features/admin/services/admin_providers.dart';

/// 관리자 홈. 들어오자마자 오늘 처리할 게 몇 건인지 보인다.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  static const Color _primary = Color(0xFF6B7AF5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(adminSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('관리자'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              summaryAsync.when(
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _ErrorBox(
                  message: '요약을 불러오지 못했어요.\n권한이 없거나 연결에 문제가 있습니다.',
                ),
                data: (summary) => _buildSummary(context, summary),
              ),
              const SizedBox(height: 24),
              const Text(
                '관리 메뉴',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 12),
              _MenuTile(
                icon: Icons.fact_check_outlined,
                title: '창고 승인',
                subtitle: '등록 신청을 확인하고 승인하거나 반려합니다',
                onTap: () => _push(context, const StorageReviewScreen()),
              ),
              _MenuTile(
                icon: Icons.people_outline,
                title: '사용자 관리',
                subtitle: '가입자 목록과 이용 정지',
                onTap: () => _push(context, const AdminUsersScreen()),
              ),
              _MenuTile(
                icon: Icons.swap_horiz,
                title: '거래 현황',
                subtitle: '예약 · 이용 중 · 종료된 이용',
                onTap: () => _push(context, const AdminTradesScreen()),
              ),
              _MenuTile(
                icon: Icons.history,
                title: '처리 기록',
                subtitle: '누가 무엇을 언제 처리했는지',
                onTap: () => _push(context, const AdminLogsScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildSummary(BuildContext context, AdminSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 처리할 게 남아 있으면 먼저 눈에 띄게 알린다.
        if (summary.pendingStorages > 0)
          _Highlight(
            icon: Icons.pending_actions,
            color: const Color(0xFFFF9800),
            background: const Color(0xFFFFF3E0),
            title: '승인 대기 ${summary.pendingStorages}건',
            message: '등록 신청이 처리를 기다리고 있어요.',
            onTap: () => _push(context, const StorageReviewScreen()),
          ),
        if (summary.overdueUsages > 0) ...[
          if (summary.pendingStorages > 0) const SizedBox(height: 10),
          _Highlight(
            icon: Icons.error_outline,
            color: const Color(0xFFD32F2F),
            background: const Color(0xFFFFEBEE),
            title: '기간이 지난 이용 ${summary.overdueUsages}건',
            message: '이용 내역으로 넘어가지 않았어요. 이관 함수를 확인해주세요.',
            onTap: () => _push(context, const AdminTradesScreen()),
          ),
        ],
        if (summary.pendingStorages > 0 || summary.overdueUsages > 0)
          const SizedBox(height: 16),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // 비율(childAspectRatio)로 두면 화면 폭에 따라 높이가 같이 줄어
          // 좁은 기기에서 내용이 넘친다. 높이를 직접 고정한다.
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 92,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
          children: [
            _StatCard(
              label: '승인 대기',
              value: summary.pendingStorages,
              color: summary.pendingStorages > 0
                  ? const Color(0xFFFF9800)
                  : _primary,
            ),
            _StatCard(
              label: '대기 중 예약',
              value: summary.waitingReservations,
              color: _primary,
            ),
            _StatCard(
              label: '이용 중',
              value: summary.activeUsages,
              color: _primary,
            ),
            _StatCard(
              label: '전체 사용자',
              value: summary.totalUsers,
              color: _primary,
              caption: summary.suspendedUsers > 0
                  ? '정지 ${summary.suspendedUsers}'
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: color.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.caption,
  });

  final String label;
  final int value;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // 시스템 글꼴을 크게 쓰는 기기에서도 넘치지 않도록 줄여서 맞춘다.
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      caption!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AdminHomeScreen._primary,
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Color(0xFFD32F2F),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/kst_time.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/features/admin/services/admin_providers.dart';

/// 예약 · 이용 중 · 종료를 한 화면에서 훑는다.
///
/// 관리자가 여기서 보고 싶은 건 "정상적으로 흐르고 있나"이므로,
/// 오래 방치된 예약과 기간이 지났는데 안 넘어간 이용을 눈에 띄게 표시한다.
class AdminTradesScreen extends StatelessWidget {
  const AdminTradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('거래 현황'),
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
          bottom: const TabBar(
            labelColor: Color(0xFF6B7AF5),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF6B7AF5),
            tabs: [
              Tab(text: '예약'),
              Tab(text: '이용 중'),
              Tab(text: '종료'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReservationList(),
            _UsageList(kind: TradeKind.usage),
            _UsageList(kind: TradeKind.ended),
          ],
        ),
      ),
    );
  }
}

class _ReservationList extends ConsumerWidget {
  const _ReservationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(adminReservationsProvider);

    return reservationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(error: error),
      data: (reservations) {
        if (reservations.isEmpty) {
          return const _EmptyView(message: '예약이 없어요.');
        }

        final now = nowKst();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index];
            // 신청한 지 사흘이 지나도록 주인이 처리하지 않은 건
            final stale =
                reservation.status == Status.waiting &&
                now.difference(toKst(reservation.createdAt)).inDays >= 3;

            return _TradeRow(
              title: '${reservation.containerIndex} 구역',
              subtitle:
                  '${_formatDate(reservation.startAt)} ~ '
                  '${_formatDate(reservation.endAt)}',
              badge: switch (reservation.status) {
                Status.waiting => '대기',
                Status.approved => '확정',
                Status.rejected => '거절',
              },
              badgeColor: switch (reservation.status) {
                Status.waiting => const Color(0xFFFF9800),
                Status.approved => const Color(0xFF2E7D32),
                Status.rejected => const Color(0xFFD32F2F),
              },
              warning: stale ? '3일 넘게 주인이 처리하지 않았어요' : null,
              footer: '신청 ${_formatDate(reservation.createdAt)}',
            );
          },
        );
      },
    );
  }
}

class _UsageList extends ConsumerWidget {
  const _UsageList({required this.kind});

  final TradeKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usagesAsync = ref.watch(adminUsagesProvider(kind));

    return usagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(error: error),
      data: (usages) {
        if (usages.isEmpty) {
          return _EmptyView(
            message: kind == TradeKind.usage
                ? '이용 중인 건이 없어요.'
                : '종료된 이용이 없어요.',
          );
        }

        final today = nowKst();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          itemCount: usages.length,
          itemBuilder: (context, index) {
            final usage = usages[index];
            // 이용 중 탭에서 종료일이 지났다면 이관 함수가 멈춘 것이다.
            final overdue =
                kind == TradeKind.usage &&
                toKst(usage.endAt).isBefore(today);

            return _TradeRow(
              title: '${usage.containerIndex} 구역',
              subtitle:
                  '${_formatDate(usage.startAt)} ~ '
                  '${_formatDate(usage.endAt)}',
              badge: kind == TradeKind.usage ? '이용 중' : '종료',
              badgeColor: kind == TradeKind.usage
                  ? const Color(0xFF6B7AF5)
                  : Colors.grey,
              warning: overdue ? '기간이 지났는데 이용 내역으로 안 넘어갔어요' : null,
              footer: '창고 ${usage.storageId}',
            );
          },
        );
      },
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}'
    '.${date.day.toString().padLeft(2, '0')}';

class _TradeRow extends StatelessWidget {
  const _TradeRow({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.footer,
    this.warning,
  });

  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final String footer;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
          ),
          const SizedBox(height: 3),
          Text(
            footer,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          if (warning != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                warning!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '불러오지 못했어요.\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], height: 1.5),
        ),
      ),
    );
  }
}

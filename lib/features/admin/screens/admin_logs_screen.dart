import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/kst_time.dart';
import 'package:jimiker/features/admin/services/admin_providers.dart';
import 'package:jimiker/services/auth_providers.dart';

/// 관리자 처리 기록.
///
/// 매니저가 여러 명이 되면 "누가 이 창고를 반려했지?"에 답할 수 있어야 한다.
/// 기록은 서버(Functions)만 쓰고 여기서는 읽기만 한다.
class AdminLogsScreen extends ConsumerWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('처리 기록'),
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
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '기록을 불러오지 못했어요.\n관리자 권한이 있는지 확인해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], height: 1.5),
              ),
            ),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return Center(
                child: Text(
                  '아직 처리한 내역이 없어요.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              itemCount: logs.length,
              itemBuilder: (context, index) =>
                  _LogRow(log: logs[index]),
            );
          },
        ),
      ),
    );
  }
}

class _LogRow extends ConsumerWidget {
  const _LogRow({required this.log});

  final AdminLog log;

  Color get _color => switch (log.action) {
    'approveStorage' => const Color(0xFF2E7D32),
    'rejectStorage' => const Color(0xFFD32F2F),
    'suspendUser' => const Color(0xFFD32F2F),
    'unsuspendUser' => const Color(0xFF2E7D32),
    _ => const Color(0xFF6B7AF5),
  };

  String _formatMoment(DateTime? value) {
    if (value == null) return '';
    final kst = toKst(value);
    final hour = kst.hour.toString().padLeft(2, '0');
    final minute = kst.minute.toString().padLeft(2, '0');
    return '${kst.year}.${kst.month.toString().padLeft(2, '0')}'
        '.${kst.day.toString().padLeft(2, '0')} $hour:$minute';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 매니저 uid만으로는 누군지 알 수 없어 닉네임을 붙여 보여준다.
    final actorAsync = ref.watch(userStreamProvider(log.actorUid));
    final actorName =
        actorAsync.value?.nickName ??
        (log.actorUid.isEmpty ? '알 수 없음' : log.actorUid);

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  log.actionLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatMoment(log.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '처리자 $actorName',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '대상 ${log.targetId}',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
          if (log.reason.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              '사유: ${log.reason}',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey[800],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

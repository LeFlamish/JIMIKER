import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/widgets/detail_section.dart';
import 'package:jimiker/core/widgets/storage_detail_sections.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/features/admin/services/admin_providers.dart';
import 'package:jimiker/services/auth_providers.dart';

/// 주인이 보낸 창고 삭제 요청을 검토하고 승인/반려한다.
///
/// 승인은 되돌릴 수 없어서, 걸려 있는 거래(이용 중·예약)를
/// 먼저 보여주고 판단하게 한다. 이용 중이 있으면 서버가 승인을 거부한다.
class StorageDeletionReviewScreen extends ConsumerStatefulWidget {
  const StorageDeletionReviewScreen({super.key, required this.storage});

  final Storage storage;

  @override
  ConsumerState<StorageDeletionReviewScreen> createState() =>
      _StorageDeletionReviewScreenState();
}

class _StorageDeletionReviewScreenState
    extends ConsumerState<StorageDeletionReviewScreen> {
  bool _isWorking = false;

  Storage get _storage => widget.storage;

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}'
      '.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ownerAsync = ref.watch(userStreamProvider(_storage.ownerId));
    final impactAsync = ref.watch(
      storageTradeImpactProvider(_storage.id ?? ''),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('삭제 요청 확인'),
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
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            DetailStatusBanner(
              icon: Icons.delete_outline,
              label: '삭제 요청',
              description: _storage.deleteRequestedAt == null
                  ? '주인이 이 창고의 삭제를 요청했어요.'
                  : '${_formatDate(_storage.deleteRequestedAt!)}에 주인이 삭제를 요청했어요.',
              color: const Color(0xFFD32F2F),
              background: const Color(0xFFFFEBEE),
            ),
            const SizedBox(height: 16),
            _buildReasonCard(),
            const SizedBox(height: 16),
            ...switch (impactAsync.value) {
              final impact? when !impact.isEmpty => [
                _buildTradeCard(impact),
                const SizedBox(height: 16),
              ],
              _ => const <Widget>[],
            },
            StorageInfoCard(storage: _storage),
            const SizedBox(height: 16),
            _buildOwnerCard(ownerAsync),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(
        impactAsync.value?.activeUsages ?? 0,
      ),
    );
  }

  Widget _buildReasonCard() {
    final reason = _storage.deleteRequestReason.trim();
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('요청 사유'),
          const SizedBox(height: 10),
          Text(
            reason.isEmpty ? '(사유를 적지 않았어요)' : reason,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: reason.isEmpty
                  ? Colors.grey[500]
                  : const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  /// 이 창고에 걸려 있는 거래. 승인이 무엇을 건드리는지 미리 보여준다.
  Widget _buildTradeCard(StorageTradeImpact impact) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('진행 중인 거래'),
          const SizedBox(height: 14),
          if (impact.activeUsages > 0)
            DetailInfoRow(
              label: '이용 중',
              value: '${impact.activeUsages}건 (있는 동안 승인 불가)',
              valueColor: const Color(0xFFD32F2F),
            ),
          if (impact.openReservations > 0)
            DetailInfoRow(
              label: '예약',
              value: '${impact.openReservations}건 (승인하면 취소)',
              valueColor: const Color(0xFFD32F2F),
            ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              [
                if (impact.activeUsages > 0)
                  '짐이 들어 있는 계약은 끊을 수 없어요. 기간이 끝난 뒤 '
                      '처리하거나, 반려로 주인에게 사유를 알려주세요.',
                if (impact.openReservations > 0)
                  '승인하면 시작 전 예약은 취소되고 예약자에게 안내가 가요.',
              ].join('\n\n'),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: Color(0xFF8D6E00),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(AsyncValue<dynamic> ownerAsync) {
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('요청한 주인'),
          const SizedBox(height: 14),
          ownerAsync.when(
            loading: () => const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              '주인 정보를 불러오지 못했어요.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            data: (owner) {
              if (owner == null) {
                return Text(
                  '탈퇴했거나 없는 계정입니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[700],
                  ),
                );
              }
              return Column(
                children: [
                  DetailInfoRow(
                    label: '닉네임',
                    value: owner.nickName.isEmpty
                        ? '(없음)'
                        : owner.nickName,
                  ),
                  DetailInfoRow(
                    label: '이메일',
                    value: owner.email.isEmpty ? '(없음)' : owner.email,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int activeUsages) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isWorking ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF757575)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '반려',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  // 이용 중이 있으면 서버가 어차피 거부한다. 미리 막아준다.
                  onPressed: _isWorking || activeUsages > 0
                      ? null
                      : _approve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    disabledBackgroundColor: const Color(0xFFE0A0A0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isWorking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          activeUsages > 0 ? '이용 중이라 승인 불가' : '삭제 승인',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('삭제를 승인할까요?'),
        content: const Text(
          '되돌릴 수 없어요.\n'
          '시작 전 예약은 취소되고 예약자에게 안내가 갑니다.\n'
          '지난 기록이 있으면 문서는 남기고 목록에서만 내려가고,\n'
          '기록이 전혀 없으면 사진까지 완전히 삭제됩니다.',
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
              '삭제 승인',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      final result = await ref
          .read(adminActionsProvider)
          .approveStorageDeletion(_storage.id ?? '');

      final notes = <String>[
        result.hardDeleted
            ? '창고를 완전히 삭제했어요.'
            : '기록 보존을 위해 창고를 목록에서 내렸어요.',
      ];
      if (result.cancelledReservations > 0) {
        notes.add('예약 ${result.cancelledReservations}건을 취소했어요.');
      }
      return notes.join(' ');
    });
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('반려 사유'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '적으신 내용이 주인에게 그대로 전달됩니다.',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '예) 이용 중인 계약이 끝난 뒤 다시 요청해주세요.',
                border: OutlineInputBorder(),
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
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(controller.text.trim()),
            child: const Text(
              '반려',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    await _run(() async {
      await ref
          .read(adminActionsProvider)
          .rejectStorageDeletion(
            storageId: _storage.id ?? '',
            reason: reason,
          );
      return '반려했어요. 주인에게 사유를 보냈어요.';
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _isWorking = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final done = await action();
      ref.invalidate(adminSummaryProvider);
      ref.invalidate(storageTradeImpactProvider(_storage.id ?? ''));
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      if (mounted) setState(() => _isWorking = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('처리하지 못했어요: ${readableAdminError(error)}'),
        ),
      );
    }
  }
}

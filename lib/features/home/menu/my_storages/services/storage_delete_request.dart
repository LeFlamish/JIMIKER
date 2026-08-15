import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';

/// 창고 삭제 요청 / 요청 취소 다이얼로그.
///
/// 삭제는 운영자가 승인해야 이뤄진다. 예약이 걸린 창고를 주인이 말없이
/// 없애버리는 일을 막기 위해서다. 목록 카드와 상세 화면이 같이 쓴다.
Future<void> showStorageDeleteRequestFlow(
  BuildContext context,
  WidgetRef ref, {
  required String storageId,
  required Storage storage,
}) {
  return storage.deleteRequested
      ? _confirmCancelRequest(context, ref, storageId)
      : _askDeleteRequest(context, ref, storageId);
}

Future<void> _askDeleteRequest(
  BuildContext context,
  WidgetRef ref,
  String storageId,
) async {
  final controller = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('창고 삭제를 요청할까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '삭제는 운영자가 확인한 뒤 처리돼요.\n'
            '· 이용 중인 계약이 있으면 승인되지 않아요.\n'
            '· 시작 전 예약은 삭제와 함께 취소되고 예약자에게 안내가 가요.\n'
            '· 지난 이용 내역이 있으면 기록 보존을 위해 목록에서만 내려가요.',
            style: TextStyle(fontSize: 13.5, height: 1.55),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '사유 (선택) — 예) 더 이상 운영하지 않아요.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
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
            '삭제 요청',
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

  final done = await ref
      .read(myStoragesProvider.notifier)
      .requestDeletion(
        storageId: storageId,
        reason: controller.text.trim(),
      );

  if (done) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('삭제 요청을 보냈어요. 운영자가 확인하면 알림으로 알려드려요.'),
      ),
    );
  }
}

Future<void> _confirmCancelRequest(
  BuildContext context,
  WidgetRef ref,
  String storageId,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('삭제 요청을 취소할까요?'),
      content: const Text(
        '운영자가 아직 처리하지 않은 요청이에요.\n'
        '요청을 거두면 창고는 지금 상태 그대로 유지돼요.',
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
            '요청 취소',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final done = await ref
      .read(myStoragesProvider.notifier)
      .cancelDeleteRequest(storageId);

  if (done) {
    messenger.showSnackBar(
      const SnackBar(content: Text('삭제 요청을 취소했어요.')),
    );
  }
}

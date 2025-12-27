import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';
import 'package:jimiker/features/home/menu/my_storages/widgets/my_storage_card.dart';

class MyStoragesScreen extends ConsumerStatefulWidget {
  const MyStoragesScreen({super.key});

  @override
  ConsumerState<MyStoragesScreen> createState() => _MyStoragesScreenState();
}

class _MyStoragesScreenState extends ConsumerState<MyStoragesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
          () => ref.read(myStoragesProvider.notifier).loadMyStorages(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myStoragesProvider);
    final storages = state.storages;
    final theme = Theme.of(context);

    ref.listen(myStoragesProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null || message.isEmpty) return;
      if (message == previous?.errorMessage) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 창고 관리'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myStoragesProvider.notifier).loadMyStorages(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : storages.isEmpty
            ? ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.store_mall_directory_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '아직 등록한 창고가 없어요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: storages.length,
          itemBuilder: (context, index) {
            final entry = storages.entries.elementAt(index);
            final storageId = entry.key;
            final storage = entry.value;
            final reservations =
                state.reservationsByStorage[storageId] ?? const [];

            return MyStorageCard(
              storage: storage,
              reservations: reservations,
              onEdit: () => _showEditDialog(
                context: context,
                storageId: storageId,
                storage: storage,
              ),
              onReservationAction: (reservation, status) {
                _confirmReservationAction(
                  context: context,
                  reservation: reservation,
                  status: status,
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: state.isUpdating
          ? SafeArea(
        child: LinearProgressIndicator(
          minHeight: 3,
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      )
          : null,
    );
  }

  Future<void> _showEditDialog({
    required BuildContext context,
    required String storageId,
    required Storage storage,
  }) async {
    final detailController = TextEditingController(
      text: storage.detailAddress,
    );
    final countController = TextEditingController(
      text: storage.count.toString(),
    );

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('창고 정보 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: detailController,
                decoration: const InputDecoration(
                  labelText: '상세 주소',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countController,
                decoration: const InputDecoration(
                  labelText: '보관함 개수',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('저장'),
            ),
          ],
        ),
      );

      if (result != true) return;

      final parsedCount = int.tryParse(countController.text) ?? storage.count;

      await ref.read(myStoragesProvider.notifier).updateStorage(
        storageId: storageId,
        detailAddress: detailController.text.trim(),
        count: parsedCount,
      );
    } finally {
      detailController.dispose();
      countController.dispose();
    }
  }

  Future<void> _confirmReservationAction({
    required BuildContext context,
    required Reservation reservation,
    required Status status,
  }) async {
    final label = status == Status.approved ? '승인' : '거절';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('예약 $label'),
        content: Text('예약을 $label 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(label),
          ),
        ],
      ),
    );

    if (result != true) return;

    await ref.read(myStoragesProvider.notifier).updateReservationStatus(
      reservation: reservation,
      status: status,
    );
  }
}
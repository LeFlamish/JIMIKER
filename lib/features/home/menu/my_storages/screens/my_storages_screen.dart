import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/features/home/menu/my_storages/screens/my_storage_detail_screen.dart';
import 'package:jimiker/features/home/menu/my_storages/screens/reservation_review_screen.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';
import 'package:jimiker/features/home/menu/my_storages/services/storage_delete_request.dart';
import 'package:jimiker/features/home/menu/my_storages/services/storage_edit_config.dart';
import 'package:jimiker/features/home/menu/register_storage/screens/register_storage_screen.dart';

import '../widgets/my_storage_card.dart';

class MyStoragesScreen extends ConsumerStatefulWidget {
  const MyStoragesScreen({super.key});

  @override
  ConsumerState<MyStoragesScreen> createState() =>
      _MyStoragesScreenState();
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

    // 에러 리스너
    ref.listen(myStoragesProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null || message.isEmpty) return;
      if (message == previous?.errorMessage) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // 배경색 적용
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(myStoragesProvider.notifier).loadMyStorages(),
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : storages.isEmpty
              ? _buildEmptyView(theme)
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 20,
                    bottom: 24,
                    left: 20,
                    right: 20,
                  ),
                  itemCount: storages.length,
                  itemBuilder: (context, index) {
                    final entry = storages.entries.elementAt(index);
                    final storageId = entry.key;
                    final storage = entry.value;
                    final reservations =
                        state.reservationsByStorage[storageId] ??
                        const [];

                    // 새로 만든 디자인 위젯 적용
                    return StorageWithReservationsCard(
                      storage: storage,
                      reservations: reservations,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyStorageDetailScreen(
                            storageId: storageId,
                            storage: storage,
                          ),
                        ),
                      ),
                      onEdit: () => _showEditDialog(
                        context: context,
                        storageId: storageId,
                        storage: storage,
                      ),
                      // 삭제는 즉시 지우지 않고 운영자에게 요청만 보낸다.
                      onDelete: () => showStorageDeleteRequestFlow(
                        context,
                        ref,
                        storageId: storageId,
                        storage: storage,
                      ),
                      onReservationTap: (reservation) {
                        // 누가 신청했는지 보고 판단할 수 있는 검토 화면으로.
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReservationReviewScreen(
                              storage: storage,
                              reservation: reservation,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
      bottomNavigationBar: state.isUpdating
          ? SafeArea(
              child: LinearProgressIndicator(
                minHeight: 3,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary
                    .withValues(alpha: 0.12),
              ),
            )
          : null,
    );
  }

  // 등록된 창고가 없을 때 뷰
  Widget _buildEmptyView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
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
    );
  }

  // 창고 수정 페이지 이동
  Future<void> _showEditDialog({
    required BuildContext context,
    required String storageId,
    required Storage storage,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegisterStorageScreen(
          editConfig: StorageEditConfig(
            storageId: storageId,
            storage: storage,
          ),
        ),
      ),
    );
  }

}

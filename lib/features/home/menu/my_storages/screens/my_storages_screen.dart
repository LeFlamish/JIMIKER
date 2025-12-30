import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';
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
                      onEdit: () => _showEditDialog(
                        context: context,
                        storageId: storageId,
                        storage: storage,
                      ),
                      onReservationTap: (reservation) {
                        // 예약 카드 탭 시 승인/거절 선택 다이얼로그 표시
                        _showReservationActionDialog(
                          context,
                          reservation,
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
                    .withOpacity(0.12),
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

  // ... imports

  Future<void> _showReservationActionDialog(
    BuildContext context,
    Reservation reservation,
  ) {
    return showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent, // 뒤 배경 투명하게 (Container의 Radius 적용을 위해)
      isScrollControlled: true, // 내용물 크기에 맞게 조절
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ), // 상단 둥글게
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 드래그 핸들 (회색 바)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 2. 타이틀
                const Text(
                  "예약 요청 관리",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "해당 예약 요청을 승인하거나 거절할 수 있습니다.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. 승인 버튼
                _buildActionButton(
                  icon: Icons.check_circle_rounded,
                  title: "예약 승인",
                  description: "예약자가 결제를 진행할 수 있도록 승인합니다.",
                  iconColor: const Color(0xFF2E7D32), // 진한 초록
                  bgColor: const Color(0xFFE8F5E9), // 연한 초록 배경
                  onTap: () {
                    Navigator.pop(context);
                    _confirmAndUpdateStatus(
                      context,
                      reservation,
                      Status.approved,
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 4. 거절 버튼
                _buildActionButton(
                  icon: Icons.cancel_rounded,
                  title: "예약 거절",
                  description: "해당 예약 요청을 거절하고 취소 처리합니다.",
                  iconColor: const Color(0xFFD32F2F), // 진한 빨강
                  bgColor: const Color(0xFFFFEBEE), // 연한 빨강 배경
                  onTap: () {
                    Navigator.pop(context);
                    _confirmAndUpdateStatus(
                      context,
                      reservation,
                      Status.rejected,
                    );
                  },
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // 커스텀 액션 버튼 위젯
  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.5), // 배경색 투명도 조절
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: bgColor.withOpacity(1.0),
            width: 1,
          ), // 테두리로 강조
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: iconColor, // 타이틀을 아이콘 색상과 맞춤
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: iconColor.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  // 최종 확인 및 상태 업데이트 호출
  Future<void> _confirmAndUpdateStatus(
    BuildContext context,
    Reservation reservation,
    Status status,
  ) async {
    final label = status == Status.approved ? '승인' : '거절';

    // 확인 다이얼로그
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('예약 $label'),
        content: Text('정말 예약을 $label 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == Status.rejected
                  ? Colors.red
                  : null,
            ),
            child: Text(label),
          ),
        ],
      ),
    );

    if (result != true) return;

    // Provider 상태 업데이트 호출
    await ref
        .read(myStoragesProvider.notifier)
        .updateReservationStatus(
          reservation: reservation,
          status: status,
        );
  }
}

// ----------------------------------------------------------------
// 새로 디자인된 UI 위젯 (기능 연결을 위해 onEdit, onReservationTap 추가)
// ----------------------------------------------------------------

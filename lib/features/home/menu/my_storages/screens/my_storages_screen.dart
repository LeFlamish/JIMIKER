import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';
import 'package:jimiker/features/home/menu/my_storages/services/storage_edit_config.dart';
import 'package:jimiker/features/home/menu/register_storage/screens/register_storage_screen.dart';

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

  // 예약 승인/거절 선택 다이얼로그 (새로 추가됨)
  Future<void> _showReservationActionDialog(
    BuildContext context,
    Reservation reservation,
  ) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: const Text('예약 승인'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAndUpdateStatus(
                    context,
                    reservation,
                    Status.approved,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.red,
                ),
                title: const Text('예약 거절'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAndUpdateStatus(
                    context,
                    reservation,
                    Status.rejected,
                  );
                },
              ),
            ],
          ),
        );
      },
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

class StorageWithReservationsCard extends StatelessWidget {
  final Storage storage;
  final List<Reservation> reservations;
  final VoidCallback onEdit; // 수정 버튼 콜백
  final Function(Reservation) onReservationTap; // 예약 카드 탭 콜백

  const StorageWithReservationsCard({
    super.key,
    required this.storage,
    required this.reservations,
    required this.onEdit,
    required this.onReservationTap,
  });

  @override
  Widget build(BuildContext context) {
    // 거절된 예약은 제외
    final visibleReservations = reservations
        .where((r) => r.status != Status.rejected)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [상단] 창고 정보
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: const Color(0xFFF0F0F0),
                    child: storage.images.isNotEmpty
                        ? Image.network(
                            storage.images.first,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFFC0C0C0),
                            size: 40,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 승인 상태 & 편집 버튼 Row
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBadge(
                            text: storage.approved
                                ? "승인 완료"
                                : "승인 대기",
                            isApproved: storage.approved,
                          ),
                          // 편집 버튼 추가
                          GestureDetector(
                            onTap: onEdit,
                            child: const Text(
                              "편집",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7AF5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        storage.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        storage.detailAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.archive_outlined,
                            size: 16,
                            color: Color(0xFF6B7AF5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "보관함 ${storage.count}개",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7AF5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 구분선
          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // [하단] 예약 목록 영역
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "예약 요청",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                if (visibleReservations.isEmpty)
                  _buildEmptyState()
                else
                  ...visibleReservations.map(
                    (r) => _buildInnerReservationCard(r),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          children: const [
            Icon(
              Icons.inbox_outlined,
              size: 32,
              color: Color(0xFFCCCCCC),
            ),
            SizedBox(height: 8),
            Text(
              "들어온 예약 요청이 없어요",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInnerReservationCard(Reservation reservation) {
    String formatDate(DateTime d) =>
        "${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}";

    return GestureDetector(
      onTap: () => onReservationTap(reservation), // 탭 이벤트 전달
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reservation.zoneIndex.isNotEmpty
                      ? "보관함 ${reservation.zoneIndex}"
                      : "보관함",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                _buildStatusText(reservation.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "${formatDate(reservation.startAt)} ~ ${formatDate(reservation.endAt)}",
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "탭해서 승인 또는 거절할 수 있어요.",
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required bool isApproved,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isApproved
              ? const Color(0xFF2E7D32)
              : const Color(0xFFFF9800),
        ),
      ),
    );
  }

  Widget _buildStatusText(Status status) {
    switch (status) {
      case Status.waiting:
        return const Text(
          "대기중",
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFFFF9800),
            fontWeight: FontWeight.bold,
          ),
        );
      case Status.approved:
        return const Text(
          "승인됨",
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
          ),
        );
      default:
        return const SizedBox();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:jimiker/core/widgets/cached_image.dart';

import '../../../../../data/models/reservation.dart';
import '../../../../../data/models/storage.dart';

class StorageWithReservationsCard extends StatelessWidget {
  final Storage storage;
  final List<Reservation> reservations;
  final VoidCallback onEdit; // 수정 버튼 콜백
  final VoidCallback onDelete; // 삭제 버튼 콜백
  final Function(Reservation) onReservationTap; // 예약 카드 탭 콜백

  const StorageWithReservationsCard({
    super.key,
    required this.storage,
    required this.reservations,
    required this.onEdit,
    required this.onDelete,
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
                        ? CachedImage(
                            imageUrl: storage.images.first,
                            width: 90,
                            height: 90,
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
                          // 편집 / 삭제 버튼
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                              const SizedBox(width: 14),
                              GestureDetector(
                                onTap: onDelete,
                                child: Text(
                                  "삭제",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
                  reservation.containerIndex.isNotEmpty
                      ? "보관함 ${reservation.containerIndex}"
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/services/auth_providers.dart';

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
                          _buildBadge(storage.reviewStatus),
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

          if (storage.reviewStatus == ReviewStatus.rejected &&
              storage.rejectReason.isNotEmpty)
            _buildRejectReason(),

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

    // 계약 금액 스냅샷이 있는 예약만 금액 줄을 보여준다. (없으면 옛 기록)
    final monthly = reservation.monthlyPrice;
    final months = reservation.months;
    final total =
        reservation.totalPrice ??
        (monthly != null && months != null ? monthly * months : null);
    final priceLine = monthly == null
        ? null
        : [
            '월 ${formatWon(monthly)}',
            if (months != null) '$months개월',
            if (total != null) '총 ${formatWon(total)}',
          ].join(' · ');

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
                      ? "${reservation.containerIndex} 구역"
                      : "보관 구역",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                _buildStatusText(reservation.status),
              ],
            ),
            const SizedBox(height: 6),
            _buildRequesterLine(reservation),
            const SizedBox(height: 4),
            Text(
              "${formatDate(reservation.startAt)} ~ ${formatDate(reservation.endAt)}",
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
            if (priceLine != null) ...[
              const SizedBox(height: 4),
              Text(
                priceLine,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                ),
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              "탭해서 요청을 검토할 수 있어요.",
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

  /// 누가 신청했는지 목록에서 바로 보이게 한다.
  Widget _buildRequesterLine(Reservation reservation) {
    return Consumer(
      builder: (context, ref, _) {
        final requesterAsync = ref.watch(
          userStreamProvider(reservation.userId),
        );
        final label = requesterAsync.when(
          data: (user) {
            final name = user?.nickName.trim() ?? '';
            return name.isEmpty ? '알 수 없는 신청자' : '$name님의 신청';
          },
          loading: () => '신청자 확인 중…',
          error: (_, __) => '신청자 정보를 불러오지 못했어요',
        );

        return Row(
          children: [
            const Icon(
              Icons.person_outline,
              size: 14,
              color: Color(0xFF6B7AF5),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 심사 상태 배지.
  ///
  /// approved 하나만 보면 "아직 안 봤다"와 "반려됐다"가 똑같이 보여서
  /// 주인은 왜 지도에 안 뜨는지 알 수가 없다. 셋을 구분해서 보여준다.
  Widget _buildBadge(ReviewStatus status) {
    final (text, color, background) = switch (status) {
      ReviewStatus.approved => (
        "승인 완료",
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
      ),
      ReviewStatus.pending => (
        "승인 대기",
        const Color(0xFFFF9800),
        const Color(0xFFFFF3E0),
      ),
      ReviewStatus.rejected => (
        "반려됨",
        const Color(0xFFD32F2F),
        const Color(0xFFFFEBEE),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// 반려 사유. 무엇을 고쳐야 다시 올라가는지 카드에서 바로 보이게 한다.
  Widget _buildRejectReason() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "반려 사유",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD32F2F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            storage.rejectReason,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Color(0xFFB71C1C),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "편집에서 고친 뒤 다시 심사를 요청할 수 있어요.",
            style: TextStyle(fontSize: 11.5, color: Color(0xFFB71C1C)),
          ),
        ],
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

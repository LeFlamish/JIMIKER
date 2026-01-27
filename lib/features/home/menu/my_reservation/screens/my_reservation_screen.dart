import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/features/home/menu/my_reservation/services/my_reservation_provider.dart';

class ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final Storage storage;
  final int? price;
  final VoidCallback? onTap;

  const ReservationCard({
    super.key,
    required this.reservation,
    required this.storage,
    required this.price,
    this.onTap,
  });

  // 날짜 포맷 (yyyy.MM.dd)
  String _formatDate(DateTime date) {
    return "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";
  }

  // 금액 포맷 (10,000원)
  String _formatCurrency(int price) {
    final format = NumberFormat('###,###,###,###');
    return "${format.format(price)}원(월)";
  }

  @override
  Widget build(BuildContext context) {
    // 기간 계산 (일수)
    final duration = reservation.endAt
        .difference(reservation.startAt)
        .inDays;

    // 상태에 따른 색상 결정
    Color statusColor;
    String statusText;
    Color bgColor;

    switch (reservation.status) {
      case Status.approved:
        final now = DateTime.now();
        if (now.isAfter(reservation.startAt) &&
            now.isBefore(reservation.endAt)) {
          statusColor = const Color(0xFF6B7AF5); // Primary
          statusText = "이용 중";
          bgColor = const Color(0xFFEEF0FF);
        } else if (now.isAfter(reservation.endAt)) {
          statusColor = Colors.grey;
          statusText = "이용 완료";
          bgColor = Colors.grey.shade100;
        } else {
          statusColor = const Color(0xFF2E7D32); // Green
          statusText = "예약 확정";
          bgColor = const Color(0xFFE8F5E9);
        }
        break;

      case Status.waiting:
        statusColor = const Color(0xFFFF9800); // Orange
        statusText = "승인 대기";
        bgColor = const Color(0xFFFFF3E0);
        break;

      case Status.rejected:
        statusColor = const Color(0xFFD32F2F); // Red
        statusText = "거절됨";
        bgColor = const Color(0xFFFFEBEE);
        break;

      default:
        // enum 값이 확장되거나 예외 케이스가 있어도 화면이 깨지지 않도록 방어
        statusColor = Colors.grey;
        statusText = "상태 확인 필요";
        bgColor = Colors.grey.shade100;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          children: [
            // [상단] 날짜 및 상태
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${_formatDate(reservation.startAt)} ~ ${_formatDate(reservation.endAt)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 구분선
            Container(height: 1, color: const Color(0xFFF0F0F0)),

            // [하단] 장소 + 보관함/가격
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 대표 이미지 (없으면 아이콘)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (storage.images.isNotEmpty)
                        ? Image.network(
                            storage.images.first,
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 62,
                                height: 62,
                                color: const Color(0xFFF5F6FA),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 62,
                            height: 62,
                            color: const Color(0xFFF5F6FA),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),

                  // 텍스트 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storage.address,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF222222),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          storage.detailAddress,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // 구역 및 가격 정보
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(
                                  6,
                                ),
                              ),
                              child: Text(
                                "보관함 ${reservation.containerIndex}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            price == null
                                ? Text(
                                    '요금 정보 없음',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[500],
                                    ),
                                  )
                                : Text(
                                    _formatCurrency(price!),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6B7AF5),
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
          ],
        ),
      ),
    );
  }
}

class ReservationListScreen extends ConsumerStatefulWidget {
  const ReservationListScreen({super.key});

  @override
  ConsumerState<ReservationListScreen> createState() =>
      _ReservationListScreenState();
}

class _ReservationListScreenState
    extends ConsumerState<ReservationListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(myReservationProvider.notifier)
          .loadMyReservations(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myReservationProvider);
    final items = state.items;

    ref.listen(myReservationProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null || message.isEmpty) return;
      if (message == previous?.errorMessage) return;
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(myReservationProvider.notifier)
              .loadMyReservations(),
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? _buildEmptyView()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ReservationCard(
                      reservation: item.reservation,
                      storage: item.storage,
                      price: item.price,
                      onTap: () {
                        debugPrint("예약 ${item.reservation.id} 클릭됨");
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.inventory_2_outlined,
          size: 56,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          '예약 내역이 없습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

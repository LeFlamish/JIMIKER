import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 날짜 및 숫자 포맷용 (pubspec.yaml에 intl 추가 권장)

// --- 1. Provided Models ---

enum Status { waiting, approved, rejected, canceled }

class Reservation {
  final String id;
  final String userId;
  final String ownerId;
  final String storageId;
  final String containerIndex; // Zone의 index와 매핑
  final DateTime createdAt;
  final DateTime startAt;
  final DateTime endAt;
  final Status status;
  final int totalPrice; // 편의상 추가 (실제로는 Zone price * 일수 계산)

  Reservation({
    required this.id,
    required this.userId,
    required this.ownerId,
    required this.storageId,
    required this.containerIndex,
    required this.createdAt,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.totalPrice,
  });
}

class Storage {
  final String? id;
  final String locationId;
  final double lat;
  final double lng;
  final String address;
  final String detailAddress;
  final int count;
  final DateTime createdAt;
  final List<String> images;
  final String ownerId;
  final double width;
  final double height;
  final Map<String, dynamic> layout;
  final bool approved;

  Storage({
    this.id,
    required this.locationId,
    required this.lat,
    required this.lng,
    required this.address,
    required this.detailAddress,
    required this.count,
    required this.createdAt,
    required this.images,
    required this.ownerId,
    required this.width,
    required this.height,
    required this.layout,
    required this.approved,
  });
}

class Zone {
  final String index;
  final double x, y, angle, width, height;
  final int price;

  Zone({
    required this.index,
    required this.x,
    required this.y,
    required this.angle,
    required this.width,
    required this.height,
    required this.price,
  });
}

// --- 2. Reservation Card Widget ---

class ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final Storage storage;
  final VoidCallback? onTap;

  const ReservationCard({
    super.key,
    required this.reservation,
    required this.storage,
    this.onTap,
  });

  // 날짜 포맷 (yyyy.MM.dd)
  String _formatDate(DateTime date) {
    return "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";
  }

  // 금액 포맷 (10,000원)
  String _formatCurrency(int price) {
    final format = NumberFormat('###,###,###,###');
    return "${format.format(price)}원";
  }

  @override
  Widget build(BuildContext context) {
    // 기간 계산 (몇 박 며칠)
    final duration = reservation.endAt
        .difference(reservation.startAt)
        .inDays;

    // 상태에 따른 색상 결정
    Color statusColor;
    String statusText;
    Color bgColor;

    switch (reservation.status) {
      case Status.approved:
        // 현재 날짜가 이용 기간 내에 있으면 '이용 중'으로 표시 가능
        final now = DateTime.now();
        if (now.isAfter(reservation.startAt) &&
            now.isBefore(reservation.endAt)) {
          statusColor = const Color(0xFF6B7AF5); // Primary Color
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
      case Status.canceled:
        statusColor = Colors.grey;
        statusText = "취소됨";
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
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Color(0xFF6B7AF5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_formatDate(reservation.startAt)} ~ ${_formatDate(reservation.endAt)}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "(${duration}일)",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  // 상태 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // [하단] 창고 정보 및 가격
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 이미지
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[100],
                      child: storage.images.isNotEmpty
                          ? Image.network(
                              storage.images.first,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.inventory_2,
                              color: Colors.grey[300],
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 텍스트 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
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
                            Text(
                              _formatCurrency(reservation.totalPrice),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B7AF5), // 강조색
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

// --- 3. Screen with Dummy Data ---

class ReservationListScreen extends StatelessWidget {
  const ReservationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // -- Dummy Data Generation --

    // 1. Storage Data
    final storageA = Storage(
      id: 's1',
      locationId: 'loc1',
      lat: 37.0,
      lng: 127.0,
      address: '서울 강남구 테헤란로 123',
      detailAddress: '지미커 타워 B1',
      count: 10,
      createdAt: DateTime.now(),
      images: ['https://via.placeholder.com/150'], // 실제 이미지 URL
      ownerId: 'owner1',
      width: 100,
      height: 100,
      layout: {},
      approved: true,
    );

    final storageB = Storage(
      id: 's2',
      locationId: 'loc2',
      lat: 37.0,
      lng: 127.0,
      address: '대구 북구 대학로 80',
      detailAddress: '경북대학교 IT대학',
      count: 5,
      createdAt: DateTime.now(),
      images: [], // 이미지 없음
      ownerId: 'owner2',
      width: 100,
      height: 100,
      layout: {},
      approved: true,
    );

    // 2. Reservation Data
    final List<Reservation> dummyReservations = [
      // Case 1: 승인 대기
      Reservation(
        id: 'r1',
        userId: 'me',
        ownerId: 'owner1',
        storageId: 's1',
        containerIndex: 'A-101',
        createdAt: DateTime.now(),
        startAt: DateTime(2025, 12, 25),
        endAt: DateTime(2026, 1, 25),
        status: Status.waiting,
        totalPrice: 150000,
      ),
      // Case 2: 이용 중 (현재 날짜가 기간 내 포함)
      Reservation(
        id: 'r2',
        userId: 'me',
        ownerId: 'owner2',
        storageId: 's2',
        containerIndex: 'B-2',
        createdAt: DateTime.now(),
        startAt: DateTime.now().subtract(const Duration(days: 5)),
        endAt: DateTime.now().add(const Duration(days: 25)),
        status: Status.approved,
        totalPrice: 80000,
      ),
      // Case 3: 이용 완료
      Reservation(
        id: 'r3',
        userId: 'me',
        ownerId: 'owner1',
        storageId: 's1',
        containerIndex: 'C-5',
        createdAt: DateTime(2023, 1, 1),
        startAt: DateTime(2023, 5, 1),
        endAt: DateTime(2023, 6, 1),
        status: Status.approved,
        totalPrice: 200000,
      ),
      // Case 4: 거절됨
      Reservation(
        id: 'r4',
        userId: 'me',
        ownerId: 'owner1',
        storageId: 's1',
        containerIndex: 'A-102',
        createdAt: DateTime.now(),
        startAt: DateTime(2025, 10, 1),
        endAt: DateTime(2025, 10, 5),
        status: Status.rejected,
        totalPrice: 30000,
      ),
    ];

    // Helper to find storage by ID
    Storage getStorage(String id) => id == 's1' ? storageA : storageB;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "내 예약 내역",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        itemCount: dummyReservations.length,
        itemBuilder: (context, index) {
          final reservation = dummyReservations[index];
          final storage = getStorage(reservation.storageId);

          return ReservationCard(
            reservation: reservation,
            storage: storage,
            onTap: () {
              print("예약 ${reservation.id} 클릭됨");
            },
          );
        },
      ),
    );
  }
}

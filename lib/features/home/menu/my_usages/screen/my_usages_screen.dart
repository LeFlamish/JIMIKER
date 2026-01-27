import 'package:flutter/material.dart';

// --- 1. Models (Usage & Storage) ---

enum UsageStatus { active, endingSoon, overdue }

class Usage {
  final String id;
  final String storageId;
  final String userId;
  final String zoneIndex; // 예: "A-101"
  final DateTime startAt;
  final DateTime endAt;
  final UsageStatus status;
  // 필요하다면 Reservation 객체를 포함할 수도 있습니다.

  Usage({
    required this.id,
    required this.storageId,
    required this.userId,
    required this.zoneIndex,
    required this.startAt,
    required this.endAt,
    required this.status,
  });
}

class Storage {
  final String id;
  final String address;
  final String detailAddress;
  final List<String> images;

  Storage({
    required this.id,
    required this.address,
    required this.detailAddress,
    required this.images,
  });
}

// --- 2. Usage Card Widget (핵심 UI) ---

class UsageCard extends StatelessWidget {
  final Usage usage;
  final Storage storage;
  final VoidCallback? onSmartKeyTap;
  final VoidCallback? onExtendTap;

  const UsageCard({
    super.key,
    required this.usage,
    required this.storage,
    this.onSmartKeyTap,
    this.onExtendTap,
  });

  // 날짜 포맷
  String _formatDate(DateTime date) {
    return "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";
  }

  // D-Day 계산
  int _calculateDDay() {
    final now = DateTime.now();
    // 시간/분/초 제거하고 날짜만 비교
    final endDate = DateTime(
      usage.endAt.year,
      usage.endAt.month,
      usage.endAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return endDate.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final dDay = _calculateDDay();

    // 상태별 UI 설정
    Color statusColor;
    String statusText;
    String dDayText;

    if (usage.status == UsageStatus.overdue) {
      statusColor = const Color(0xFFD32F2F); // Red
      statusText = "연체 중";
      dDayText = "D+${dDay.abs()}";
    } else if (dDay <= 3) {
      statusColor = const Color(0xFFFF9800); // Orange
      statusText = "종료 임박";
      dDayText = "D-$dDay";
    } else {
      statusColor = const Color(0xFF6B7AF5); // Primary Blue
      statusText = "이용 중";
      dDayText = "D-$dDay";
    }

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
        children: [
          // [상단] D-Day 및 창고 정보
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: const Color(0xFFF0F0F0),
                    child: storage.images.isNotEmpty
                        ? Image.network(
                            storage.images.first,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey,
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
                      // 상태 뱃지 & D-Day
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
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            dDayText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "보관함 ${usage.zoneIndex} · ~${_formatDate(usage.endAt)}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // [하단] 액션 버튼 (스마트키, 연장하기)
          Row(
            children: [
              // 스마트키 버튼 (강조)
              Expanded(
                child: InkWell(
                  onTap: onSmartKeyTap,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_open_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "스마트키",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 이용 연장 버튼
              Expanded(
                child: InkWell(
                  onTap: onExtendTap,
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.update_rounded,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "이용 연장",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- 3. Screen (Dummy Data) ---

class UsageListScreen extends StatelessWidget {
  const UsageListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 더미 데이터 생성
    final storage1 = Storage(
      id: 's1',
      address: '서울 강남구 테헤란로 123',
      detailAddress: '지하 1층',
      images: ['https://via.placeholder.com/150'],
    );

    final storage2 = Storage(
      id: 's2',
      address: '대구 북구 대학로 80',
      detailAddress: 'IT대학 2호관',
      images: [],
    );

    final usages = [
      // Case 1: 일반 이용 중
      Usage(
        id: 'u1',
        storageId: 's1',
        userId: 'user1',
        zoneIndex: 'A-101',
        startAt: DateTime.now().subtract(const Duration(days: 10)),
        endAt: DateTime.now().add(const Duration(days: 20)), // 20일 남음
        status: UsageStatus.active,
      ),
      // Case 2: 종료 임박 (3일 이하)
      Usage(
        id: 'u2',
        storageId: 's2',
        userId: 'user1',
        zoneIndex: 'B-05',
        startAt: DateTime.now().subtract(const Duration(days: 28)),
        endAt: DateTime.now().add(const Duration(days: 2)), // 2일 남음
        status: UsageStatus.endingSoon,
      ),
      // Case 3: 연체 중
      Usage(
        id: 'u3',
        storageId: 's1',
        userId: 'user1',
        zoneIndex: 'C-11',
        startAt: DateTime.now().subtract(const Duration(days: 35)),
        endAt: DateTime.now().subtract(
          const Duration(days: 2),
        ), // 2일 지남
        status: UsageStatus.overdue,
      ),
    ];

    Storage getStorage(String id) => id == 's1' ? storage1 : storage2;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "이용 중인 보관함",
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
        itemCount: usages.length,
        itemBuilder: (context, index) {
          final usage = usages[index];
          return UsageCard(
            usage: usage,
            storage: getStorage(usage.storageId),
            onSmartKeyTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${usage.zoneIndex} 보관함 문이 열렸습니다!'),
                ),
              );
            },
            onExtendTap: () {
              print('연장하기 클릭: ${usage.id}');
            },
          );
        },
      ),
    );
  }
}

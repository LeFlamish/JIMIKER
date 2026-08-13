import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/zone_provider.dart';
import 'package:jimiker/features/home/menu/chat/services/open_direct_chat.dart';
import 'package:jimiker/services/auth_providers.dart';

class ReservationCard extends ConsumerStatefulWidget {
  const ReservationCard({super.key, required this.storage});

  final Storage storage;

  @override
  ConsumerState<ReservationCard> createState() =>
      _ReservationCardState();
}

class _ReservationCardState extends ConsumerState<ReservationCard> {
  DateTime? _selectedDate;
  int _selectedMonth = 1;
  bool _isSubmitting = false;
  bool _isLoadingDates = false; // 날짜 로딩 상태 표시용

  final List<int> _monthList = List.generate(
    12,
    (index) => index + 1,
  );

  final Color _primaryColor = const Color(0xFF4A65F0);
  final Color _inputFillColor = const Color(0xFFEEF0F5);

  Future<List<DateTimeRange>> _fetchAllBlockedRanges(
    String zoneIndex,
  ) async {
    final firestore = ref.read(firestoreProvider);
    final storageId = widget.storage.id;

    if (storageId == null) return [];

    try {
      // 1. Reservations 쿼리 (거절된 건은 아래에서 걸러낸다)
      final reservationQuery = firestore
          .collection('reservations')
          .where('storageId', isEqualTo: storageId)
          .where('containerIndex', isEqualTo: zoneIndex)
          .get();

      // 2. Usages 쿼리 (이미 사용 중인 내역)
      // usages 컬렉션 구조가 startAt, endAt을 가지고 있다고 가정
      final usageQuery = firestore
          .collection('usages')
          .where('storageId', isEqualTo: storageId)
          .where('containerIndex', isEqualTo: zoneIndex)
          .get();

      // 3. 두 쿼리를 병렬로 실행하여 시간 단축
      final results = await Future.wait([
        reservationQuery,
        usageQuery,
      ]);

      final reservationSnapshot = results[0];
      final usageSnapshot = results[1];

      List<DateTimeRange> ranges = [];

      // 헬퍼 함수: 스냅샷에서 날짜 범위 추출
      void addRangesFromDocs(
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
        for (var doc in docs) {
          final data = doc.data();

          // 거절된 예약은 그 기간을 막지 않는다.
          // (주인이 거절하면 곧바로 다시 예약할 수 있어야 한다.
          //  usages에는 status가 없어서 항상 통과한다.)
          if (data['status'] == Status.rejected.name) continue;

          final startTimestamp = data['startAt'] as Timestamp?;
          final endTimestamp = data['endAt'] as Timestamp?;

          if (startTimestamp != null && endTimestamp != null) {
            ranges.add(
              DateTimeRange(
                start: startTimestamp.toDate(),
                end: endTimestamp.toDate(),
              ),
            );
          }
        }
      }

      // 두 결과 합치기
      addRangesFromDocs(reservationSnapshot.docs);
      addRangesFromDocs(usageSnapshot.docs);

      return ranges;
    } catch (e) {
      debugPrint('블락된 날짜 정보 불러오기 실패: $e');
      return [];
    }
  }

  bool _isDateSelectable(
    DateTime day,
    List<DateTimeRange> blockedRanges,
  ) {
    // 날짜의 시간 성분 제거 (순수 날짜 비교)
    final DateTime tentativeStart = DateTime(
      day.year,
      day.month,
      day.day,
    );

    // 종료일 계산 (선택한 개월 수 반영)
    final DateTime tentativeEnd = DateTime(
      day.year,
      day.month + _selectedMonth,
      day.day,
    );

    for (var range in blockedRanges) {
      // 겹침 공식: (StartA < EndB) && (EndA > StartB)
      bool isOverlapping =
          tentativeStart.isBefore(range.end) &&
          tentativeEnd.isAfter(range.start);

      if (isOverlapping) {
        return false; // 선택 불가
      }
    }
    return true; // 선택 가능
  }

  Future<void> _pickDate() async {
    // 1. 구역 선택 여부 확인
    final zones = ref.read(zoneProvider);
    final selectedIndex = ref.read(selectedZoneProvider);
    final zone = _findZoneByIndex(zones, selectedIndex);

    if (zone == null || zone.index.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 예약할 구역을 선택해주세요.')),
      );
      return;
    }

    setState(() => _isLoadingDates = true);

    // 2. 예약된 날짜들 가져오기
    final reservedRanges = await _fetchAllBlockedRanges(zone.index);

    setState(() => _isLoadingDates = false);

    if (!mounted) return;

    final DateTime now = DateTime.now();
    // 기준일: 이미 선택된 날짜가 있으면 그 날짜, 없으면 오늘
    // 단, 과거 날짜는 선택 불가하므로 오늘보다 이전이면 오늘로 설정
    DateTime baseDate = _selectedDate ?? now;
    if (baseDate.isBefore(DateTime(now.year, now.month, now.day))) {
      baseDate = DateTime(now.year, now.month, now.day);
    }

    // 2. 가장 가까운 "예약 가능한 날짜" 찾기 (핵심 로직)
    DateTime? validInitialDate;

    // 오늘부터 1년 뒤까지만 탐색 (무한 루프 방지)
    for (int i = 0; i < 365; i++) {
      final DateTime candidate = baseDate.add(Duration(days: i));
      if (_isDateSelectable(candidate, reservedRanges)) {
        validInitialDate = candidate;
        break; // 찾았으면 중단
      }
    }

    // 만약 1년 내에 예약 가능한 날짜가 아예 없다면?
    if (validInitialDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('향후 1년간 예약 가능한 날짜가 없습니다.')),
      );
      return;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: validInitialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2030),
      selectableDayPredicate: (day) =>
          _isDateSelectable(day, reservedRanges),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Zone? _findZoneByIndex(List<Zone> zones, String? index) {
    if (index == null || index.isEmpty) return null;
    for (final z in zones) {
      if (z.index == index) return z;
    }
    return null;
  }

  /// 창고 주인과의 1:1 채팅방을 연다.
  ///
  /// 이미 상대와의 방이 있으면 그 방을 그대로 열고, 없으면 새 방 id만 만들어 들어간다.
  /// 이 시점에는 Firestore에 아무것도 쓰지 않기 때문에, 아무 말도 안 하고 나오면
  /// 방은 저장되지 않는다. (첫 메시지를 보내는 순간 방이 만들어진다.)
  Future<void> _openChatWithOwner({
    required String uid,
    required String ownerId,
    NavigatorState? navigator,
  }) async {
    final target =
        navigator ?? (mounted ? Navigator.of(context) : null);
    if (target == null) return;

    await openDirectChatRoom(
      navigator: target,
      firestore: ref.read(firestoreProvider),
      uid: uid,
      opponentUid: ownerId,
    );
  }

  Future<void> _oneToOneInquiry({required Zone? zone}) async {
    try {
      if (zone == null || zone.index.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예약할 구역을 선택해주세요.')),
        );
        return;
      }

      final authController = ref.read(
        authControllerProvider.notifier,
      );
      final signedIn = await authController.checkSignIn(context);
      if (!signedIn) return;

      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) return;

      await _openChatWithOwner(
        uid: user.uid,
        ownerId: widget.storage.ownerId,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('채팅방을 열지 못했어요.')));
    }
  }

  Future<void> _submitReservation({required Zone? zone}) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작 날짜를 선택해주세요.')));
      return;
    }
    if (zone == null || zone.index.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('예약할 구역을 선택해주세요.')),
      );
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);
    final signedIn = await authController.checkSignIn(context);
    if (!signedIn || !mounted) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final DateTime startAt = _selectedDate!;
    final DateTime endAt = DateTime(
      startAt.year,
      startAt.month + _selectedMonth,
      startAt.day,
    );

    final storageId = widget.storage.id;
    final ownerId = widget.storage.ownerId;
    if (storageId == null || storageId.isEmpty || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('창고 정보가 올바르지 않아요.')),
      );
      return;
    }

    final firestore = ref.read(firestoreProvider);
    // 바텀시트를 닫은 뒤에도 써야 하므로 미리 잡아둔다.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    var isReserved = false;
    try {
      final reservationRef = firestore
          .collection('reservations')
          .doc();

      final reservation = Reservation(
        id: reservationRef.id,
        userId: user.uid,
        ownerId: ownerId,
        storageId: storageId,
        containerIndex: zone.index,
        createdAt: DateTime.now(),
        startAt: startAt,
        endAt: endAt,
        status: Status.waiting,
      );

      final batch = firestore.batch();
      batch.set(reservationRef, {
        ...reservation.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'startAt': Timestamp.fromDate(startAt.toUtc()),
        'endAt': Timestamp.fromDate(endAt.toUtc()),
      });

      await batch.commit();
      isReserved = true;

      messenger.showSnackBar(
        const SnackBar(content: Text('예약이 완료되었어요.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('예약에 실패했어요: $error')),
      );
    } finally {
      // 이미 닫힌 뒤라면(사용자가 시트를 내렸다면) 다시 pop하지 않는다.
      if (mounted) {
        setState(() => _isSubmitting = false);
        navigator.pop(); // 예약 바텀시트 닫기
      }
    }

    if (!isReserved) return;

    // 예약과 동시에 주인과의 1:1 채팅방으로 들어간다.
    try {
      await _openChatWithOwner(
        uid: user.uid,
        ownerId: ownerId,
        navigator: navigator,
      );
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('채팅방을 열지 못했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 핵심: zoneProvider도 watch해야 “선택된 구역/가격”이 즉시 갱신됩니다.
    final zones = ref.watch(zoneProvider);
    final selectedIndex = ref.watch(selectedZoneProvider);
    final zone = _findZoneByIndex(zones, selectedIndex);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '선택된 구역',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                zone != null ? 'Zone ${zone.index}' : '구역을 선택해주세요',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: zone != null
                      ? _primaryColor
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
          if (zone != null) ...[
            const SizedBox(height: 4),
            Text(
              '가격: ${zone.price}원',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),

          const Text(
            '시작날짜 선택',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _isLoadingDates ? null : _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: _inputFillColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  // 로딩 중이면 인디케이터, 아니면 날짜 텍스트
                  if (_isLoadingDates)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Text(
                      _selectedDate == null
                          ? '날짜를 선택해주세요'
                          : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _selectedDate == null
                            ? Colors.grey[600]
                            : Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            '예약기간 선택',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _inputFillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                ),
                isExpanded: true,
                menuMaxHeight: 250,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: Colors.white,
                items: _monthList.map((value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      '$value개월',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null)
                    setState(() => _selectedMonth = newValue);
                },
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 50,
            child: TextButton(
              onPressed: () => _oneToOneInquiry(zone: zone),
              style: TextButton.styleFrom(
                backgroundColor: _inputFillColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '1 대 1 문의',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _submitReservation(zone: zone),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      '예약하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

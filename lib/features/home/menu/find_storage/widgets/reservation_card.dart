import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/zone_provider.dart';
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

  final List<int> _monthList = List.generate(
    12,
    (index) => index + 1,
  );

  final Color _primaryColor = const Color(0xFF4A65F0);
  final Color _inputFillColor = const Color(0xFFEEF0F5);

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2030),
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
    if (!signedIn) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final DateTime startAt = _selectedDate!;
    final DateTime endAt = DateTime(
      startAt.year,
      startAt.month + _selectedMonth,
      startAt.day,
    );

    final firestore = ref.read(firestoreProvider);

    setState(() => _isSubmitting = true);

    try {
      final storageId = widget.storage.id;
      if (storageId == null || storageId.isEmpty) {
        throw Exception('storage.id가 비어있습니다.');
      }

      final ownerId = widget.storage.ownerId;
      if (ownerId.isEmpty) {
        throw Exception('storage.ownerId가 비어있습니다.');
      }

      final reservationRef = firestore
          .collection('reservations')
          .doc();
      final chatRoomRef = firestore
          .collection('chat_rooms')
          .doc('reservation_${reservationRef.id}');

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

      final addressLabel =
          widget.storage.address.substring(5) +
          "-" +
          widget.storage.detailAddress;
      final roomName = '예약 문의 - $addressLabel (${zone.index})';

      final batch = firestore.batch();
      batch.set(reservationRef, {
        ...reservation.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'startAt': Timestamp.fromDate(startAt.toUtc()),
        'endAt': Timestamp.fromDate(endAt.toUtc()),
      });

      batch.set(chatRoomRef, {
        'roomName': roomName,
        'participantUids': [user.uid, ownerId],
        'lastMessage': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('예약이 완료되었어요.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('예약에 실패했어요: $error')));
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();
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
            onTap: _pickDate,
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
              onPressed: () => print('1:1 문의 클릭'),
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

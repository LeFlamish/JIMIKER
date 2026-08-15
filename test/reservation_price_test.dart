import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/data/models/ended.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/features/home/menu/find_storage/services/reservation_actions.dart';

Reservation _reservation({
  int? monthlyPrice,
  int? months,
  int? totalPrice,
}) {
  return Reservation(
    id: 'r1',
    userId: 'u1',
    ownerId: 'o1',
    storageId: 's1',
    containerIndex: 'A',
    createdAt: DateTime(2026, 8, 1),
    startAt: DateTime(2026, 9, 1),
    endAt: DateTime(2026, 12, 1),
    status: Status.waiting,
    monthlyPrice: monthlyPrice,
    months: months,
    totalPrice: totalPrice,
  );
}

void main() {
  group('계약 금액 저장', () {
    test('금액이 있으면 문서에 함께 담긴다', () {
      final map = _reservation(
        monthlyPrice: 50000,
        months: 3,
        totalPrice: 150000,
      ).toMap();

      expect(map['monthlyPrice'], 50000);
      expect(map['months'], 3);
      expect(map['totalPrice'], 150000);
    });

    test('금액이 없는 예전 기록은 빈 필드를 만들지 않는다', () {
      // null을 그대로 쓰면 "금액이 0원인 계약"과 구분되지 않는다.
      final map = _reservation().toMap();

      expect(map.containsKey('monthlyPrice'), isFalse);
      expect(map.containsKey('months'), isFalse);
      expect(map.containsKey('totalPrice'), isFalse);
    });

    test('copyWith로 상태를 바꿔도 금액은 유지된다', () {
      // 주인이 승인하면 status만 바뀐다. 금액이 날아가면 안 된다.
      final approved = _reservation(
        monthlyPrice: 50000,
        months: 3,
        totalPrice: 150000,
      ).copyWith(status: Status.approved);

      expect(approved.status, Status.approved);
      expect(approved.monthlyPrice, 50000);
      expect(approved.totalPrice, 150000);
    });

    test('이용·종료 기록도 같은 금액 필드를 갖는다', () {
      // 예약 → 이용 → 내역으로 넘어가는 동안 금액이 따라가야 한다.
      final usage = Usage(
        id: 'x',
        userId: 'u1',
        ownerId: 'o1',
        storageId: 's1',
        containerIndex: 'A',
        startAt: DateTime(2026, 9, 1),
        endAt: DateTime(2026, 12, 1),
        createdAt: DateTime(2026, 8, 1),
        monthlyPrice: 50000,
        months: 3,
        totalPrice: 150000,
      );
      final ended = Ended(
        id: 'x',
        userId: 'u1',
        ownerId: 'o1',
        storageId: 's1',
        containerIndex: 'A',
        startAt: DateTime(2026, 9, 1),
        endAt: DateTime(2026, 12, 1),
        createdAt: DateTime(2026, 8, 1),
        monthlyPrice: 50000,
        months: 3,
        totalPrice: 150000,
      );

      expect(usage.toMap()['totalPrice'], 150000);
      expect(ended.toMap()['totalPrice'], 150000);
    });

    test('저장했다 읽어도 같은 순간이다', () {
      // Timestamp는 시간대가 없는 절대 시각이다. 기기 시간대가 달라도
      // 같은 순간으로 남아야 예약 기간이 하루씩 밀리지 않는다.
      final reservation = _reservation();
      final map = reservation.toMap();

      expect(
        (map['startAt'] as Timestamp).toDate().toUtc(),
        reservation.startAt.toUtc(),
      );
      expect(
        (map['endAt'] as Timestamp).toDate().toUtc(),
        reservation.endAt.toUtc(),
      );
    });
  });

  group('readableReservationError', () {
    FirebaseFunctionsException error(String code, String message) =>
        FirebaseFunctionsException(code: code, message: message);

    test('서버가 보낸 한글 안내를 그대로 보여준다', () {
      expect(
        readableReservationError(
          error('already-exists', '그 기간에는 이미 예약이 있어요. 다른 날짜를 골라주세요.'),
        ),
        contains('이미 예약이 있어요'),
      );
    });

    test('배포가 안 된 경우를 따로 안내한다', () {
      // 함수가 없으면 Firebase가 영문 NOT_FOUND를 그대로 돌려준다.
      // 서버가 던지는 not-found와 헷갈리면 원인을 못 찾는다.
      final message = readableReservationError(
        error('not-found', 'NOT_FOUND'),
      );

      expect(message, contains('배포'));
      expect(message, contains('firebase deploy'));
    });

    test('서버가 던진 not-found는 그대로 보여준다', () {
      expect(
        readableReservationError(error('not-found', '창고를 찾을 수 없습니다.')),
        '창고를 찾을 수 없습니다.',
      );
    });

    test('모르는 오류도 사람이 읽을 수 있게 바꾼다', () {
      // 예외를 그대로 찍으면 스택이 사용자에게 보인다.
      final message = readableReservationError(StateError('boom'));

      expect(message, isNot(contains('StateError')));
      expect(message, contains('예약하지 못했어요'));
    });
  });
}

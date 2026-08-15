import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/user.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/home/menu/my_storages/screens/reservation_review_screen.dart';
import 'package:jimiker/features/home/menu/my_storages/widgets/my_storage_card.dart';
import 'package:jimiker/services/auth_providers.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

Storage _storage() {
  return Storage(
    id: 's1',
    locationId: 'l1',
    lat: 37.5,
    lng: 127,
    address: '서울시 어딘가 12-3',
    detailAddress: '지하 1층',
    count: 1,
    createdAt: DateTime(2026, 8, 1),
    images: const [],
    ownerId: 'owner1',
    width: 10,
    height: 8,
    layout: {'lines': <Line>[], 'doors': <Offset>{}},
    approved: true,
  );
}

Zone _zone() => Zone(
  index: 'A',
  x: 0,
  y: 0,
  angle: 0,
  width: 2,
  height: 3,
  price: 70000,
);

AppUser _requester({bool suspended = false}) => AppUser(
  uid: 'u1',
  email: 'guest@example.com',
  nickName: '짐보관러',
  photoURL: '',
  fcmToken: '',
  advertisement: false,
  userType: UserType.user,
  suspended: suspended,
  createdAt: DateTime(2026, 1, 5),
);

Reservation _reservation({
  Status status = Status.waiting,
  int? monthlyPrice = 50000,
  int? months = 3,
  int? totalPrice = 150000,
}) {
  return Reservation(
    id: 'r1',
    userId: 'u1',
    ownerId: 'owner1',
    storageId: 's1',
    containerIndex: 'A',
    createdAt: DateTime(2026, 8, 1),
    startAt: DateTime(2026, 9, 1),
    endAt: DateTime(2026, 12, 1),
    status: status,
    monthlyPrice: monthlyPrice,
    months: months,
    totalPrice: totalPrice,
  );
}

ProviderContainer _makeContainer({bool suspended = false}) {
  final container = ProviderContainer(
    overrides: [
      userStreamProvider('u1').overrideWith(
        (ref) => Stream.value(_requester(suspended: suspended)),
      ),
      storageZonesProvider(
        's1',
      ).overrideWith((ref) async => [_zone()]),
    ],
  );
  return container;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Reservation reservation,
  bool suspended = false,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = _makeContainer(suspended: suspended);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: ReservationReviewScreen(
          storage: _storage(),
          reservation: reservation,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('ReservationReviewScreen', () {
    testWidgets('대기 중 요청: 신청자와 조건, 승인·거절 버튼이 보인다', (tester) async {
      await _pumpScreen(tester, reservation: _reservation());

      // 누가 신청했는지
      expect(find.text('짐보관러'), findsOneWidget);
      expect(find.textContaining('가입'), findsOneWidget);
      expect(find.text('1:1 채팅으로 물어보기'), findsOneWidget);

      // 어떤 조건인지 (계약 스냅샷 금액)
      expect(find.text('A 구역 · 2×3m'), findsOneWidget);
      expect(find.text('월 요금 (계약)'), findsOneWidget);
      expect(find.text('50,000원'), findsOneWidget);
      expect(find.text('150,000원'), findsOneWidget);
      expect(find.text('3개월'), findsOneWidget);

      // 판단 버튼
      expect(find.text('승인'), findsOneWidget);
      expect(find.text('거절'), findsOneWidget);
    });

    testWidgets('계약 스냅샷이 없는 옛 기록은 현재 월 요금으로 보여준다', (tester) async {
      await _pumpScreen(
        tester,
        reservation: _reservation(
          monthlyPrice: null,
          months: null,
          totalPrice: null,
        ),
      );

      expect(find.text('현재 월 요금'), findsOneWidget);
      expect(find.text('월 요금 (계약)'), findsNothing);
      // 구역의 현재 가격 70,000원 × 어림 3개월
      expect(find.text('70,000원'), findsOneWidget);
      expect(find.text('210,000원'), findsOneWidget);
    });

    testWidgets('승인된 예약은 예약 취소 버튼만 남는다', (tester) async {
      await _pumpScreen(
        tester,
        reservation: _reservation(status: Status.approved),
      );

      expect(find.text('승인됨'), findsOneWidget);
      expect(find.text('예약 취소 (거절로 변경)'), findsOneWidget);
      expect(find.text('승인'), findsNothing);
      expect(find.text('거절'), findsNothing);
    });

    testWidgets('거절된 요청에는 버튼이 없다', (tester) async {
      await _pumpScreen(
        tester,
        reservation: _reservation(status: Status.rejected),
      );

      expect(find.text('거절됨'), findsOneWidget);
      expect(find.text('승인'), findsNothing);
      expect(find.text('거절'), findsNothing);
      expect(find.text('예약 취소 (거절로 변경)'), findsNothing);
    });

    testWidgets('정지된 계정이면 승인 전에 경고를 보여준다', (tester) async {
      await _pumpScreen(
        tester,
        reservation: _reservation(),
        suspended: true,
      );

      expect(
        find.text('이용이 정지된 계정입니다. 승인 전에 확인해주세요.'),
        findsOneWidget,
      );
    });

    testWidgets('거절을 누르면 바로 처리하지 않고 한 번 더 묻는다', (tester) async {
      await _pumpScreen(tester, reservation: _reservation());

      await tester.tap(find.text('거절'));
      await tester.pump();

      expect(find.text('이 예약을 거절할까요?'), findsOneWidget);
    });
  });

  group('StorageWithReservationsCard 예약 줄', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required List<Reservation> reservations,
      void Function(Reservation)? onTap,
    }) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StorageWithReservationsCard(
                  storage: _storage(),
                  reservations: reservations,
                  onEdit: () {},
                  onDelete: () {},
                  onReservationTap: onTap ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('신청자 이름과 계약 금액이 목록에서 바로 보인다', (tester) async {
      await pumpCard(tester, reservations: [_reservation()]);

      expect(find.text('짐보관러님의 신청'), findsOneWidget);
      expect(
        find.text('월 50,000원 · 3개월 · 총 150,000원'),
        findsOneWidget,
      );
      expect(find.text('탭해서 요청을 검토할 수 있어요.'), findsOneWidget);
    });

    testWidgets('예약 줄을 탭하면 해당 예약이 전달된다', (tester) async {
      Reservation? tapped;
      await pumpCard(
        tester,
        reservations: [_reservation()],
        onTap: (reservation) => tapped = reservation,
      );

      await tester.tap(find.text('A 구역'));
      await tester.pump();

      expect(tapped?.id, 'r1');
    });
  });
}

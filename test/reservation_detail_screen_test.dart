import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/home/menu/my_reservation/screens/reservation_detail_screen.dart';
import 'package:jimiker/services/storage_zones_provider.dart';
import 'package:jimiker/core/widgets/storage_layout_view.dart';

const _storageId = 's1';

Storage _storage({List<String> images = const []}) {
  return Storage(
    id: _storageId,
    locationId: 'l1',
    lat: 37.5,
    lng: 127.0,
    address: '서울시 어딘가 123',
    detailAddress: '지하 1층',
    count: 3,
    createdAt: DateTime(2026, 1, 1),
    images: images,
    ownerId: 'owner',
    width: 300,
    height: 240,
    layout: {
      'lines': <Line>[
        Line(start: const Offset(0, 0), end: const Offset(300, 0)),
        Line(start: const Offset(300, 0), end: const Offset(300, 240)),
        Line(start: const Offset(300, 240), end: const Offset(0, 240)),
        Line(start: const Offset(0, 240), end: const Offset(0, 0)),
      ],
      'doors': <Offset>{const Offset(150, 0)},
    },
    approved: true,
  );
}

Reservation _reservation({Status status = Status.approved}) {
  return Reservation(
    id: 'r1',
    userId: 'me',
    ownerId: 'owner',
    storageId: _storageId,
    containerIndex: 'B',
    createdAt: DateTime(2026, 8, 1),
    startAt: DateTime(2026, 9, 1),
    endAt: DateTime(2026, 12, 1),
    status: status,
  );
}

List<Zone> _zones() {
  return [
    Zone(index: 'A', x: 30, y: 30, angle: 0, width: 2, height: 2, price: 10000),
    Zone(index: 'B', x: 150, y: 30, angle: 0, width: 2, height: 3, price: 20000),
    Zone(index: 'C', x: 30, y: 150, angle: 0, width: 3, height: 2, price: 30000),
  ];
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  Status status = Status.approved,
  List<String> images = const [],
  int? price = 20000,
}) async {
  // 기본 테스트 화면(800x600)에는 페이지가 다 안 들어가서
  // ListView가 아래쪽 카드를 아예 만들지 않는다. 화면을 길게 잡아준다.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageZonesProvider(_storageId).overrideWith(
          (ref) async => _zones(),
        ),
      ],
      child: MaterialApp(
        home: ReservationDetailScreen(
          reservation: _reservation(status: status),
          storage: _storage(images: images),
          price: price,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('StorageLayoutView', () {
    testWidgets('구역을 모두 그리고 레이아웃 오류가 없다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageLayoutView(
              storage: _storage(),
              zones: _zones(),
              highlightedZoneIndex: 'B',
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('지형도가 없으면 안내 문구를 보여준다', (tester) async {
      final emptyStorage = Storage(
        id: _storageId,
        locationId: 'l1',
        lat: 0,
        lng: 0,
        address: '주소',
        detailAddress: '',
        count: 0,
        createdAt: DateTime(2026, 1, 1),
        images: const [],
        ownerId: 'owner',
        width: 0,
        height: 0,
        layout: {'lines': <Line>[], 'doors': <Offset>{}},
        approved: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageLayoutView(
              storage: emptyStorage,
              zones: const [],
              highlightedZoneIndex: 'A',
            ),
          ),
        ),
      );

      expect(find.text('지형도 정보가 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReservationDetailScreen', () {
    testWidgets('예약 정보와 지형도, 버튼이 모두 보인다', (tester) async {
      await _pumpDetail(tester);

      expect(find.text('예약 상세'), findsOneWidget);
      expect(find.text('예약 확정'), findsOneWidget);
      expect(find.text('서울시 어딘가 123'), findsOneWidget);
      expect(find.text('창고 지형도'), findsOneWidget);
      expect(find.text('B 구역'), findsOneWidget);
      expect(find.text('1 대 1 문의'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('내 구역이 범례에 표시된다', (tester) async {
      await _pumpDetail(tester);

      expect(find.text('내 보관 구역 (B)'), findsOneWidget);
      expect(find.text('다른 구역'), findsOneWidget);
    });

    testWidgets('이용 개월과 총 금액을 계산해서 보여준다', (tester) async {
      await _pumpDetail(tester);

      // 2026.09.01 ~ 2026.12.01 = 3개월, 20,000원 * 3
      expect(find.text('3개월'), findsOneWidget);
      expect(find.text('60,000원'), findsOneWidget);
    });

    testWidgets('요금 정보가 없으면 금액 자리를 비워둔다', (tester) async {
      await _pumpDetail(tester, price: null);

      expect(find.text('정보 없음'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('거절된 예약은 내역 삭제 버튼으로 바뀐다', (tester) async {
      await _pumpDetail(tester, status: Status.rejected);

      expect(find.text('거절됨'), findsOneWidget);
      expect(find.text('내역 삭제'), findsOneWidget);
      expect(find.text('예약 취소'), findsNothing);
    });

    testWidgets('승인 대기 상태를 안내한다', (tester) async {
      await _pumpDetail(tester, status: Status.waiting);

      expect(find.text('승인 대기'), findsOneWidget);
      expect(find.text('창고 주인의 승인을 기다리는 중이에요.'), findsOneWidget);
    });

    testWidgets('대기중인 예약은 바로 취소할 수 있다', (tester) async {
      await _pumpDetail(tester, status: Status.waiting);

      expect(find.text('예약 취소'), findsOneWidget);
      expect(find.text('취소 요청'), findsNothing);

      await tester.tap(find.text('예약 취소'));
      await tester.pumpAndSettle();

      expect(find.text('예약을 취소할까요?'), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
    });

    testWidgets('확정된 예약은 바로 취소하지 못하고 취소 요청만 된다', (tester) async {
      await _pumpDetail(tester, status: Status.approved);

      expect(find.text('취소 요청'), findsOneWidget);
      expect(find.text('예약 취소'), findsNothing);
      expect(find.text('내역 삭제'), findsNothing);
    });

    testWidgets('취소 요청을 누르면 문의로 안내하는 다이얼로그가 뜬다', (tester) async {
      await _pumpDetail(tester, status: Status.approved);

      await tester.tap(find.text('취소 요청'));
      await tester.pumpAndSettle();

      expect(find.text('확정된 예약이에요'), findsOneWidget);
      expect(
        find.textContaining('창고 주인에게 문의로 취소를 요청해 주세요.'),
        findsOneWidget,
      );
      expect(find.text('문의하기'), findsOneWidget);

      // 닫기를 누르면 아무 일도 일어나지 않는다.
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('확정된 예약이에요'), findsNothing);
    });
  });
}

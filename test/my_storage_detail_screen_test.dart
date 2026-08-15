import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/data/models/user.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/home/menu/my_storages/screens/my_storage_detail_screen.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';
import 'package:jimiker/services/auth_providers.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

Storage _storage({
  bool deleteRequested = false,
  ReviewStatus reviewStatus = ReviewStatus.approved,
}) {
  return Storage(
    id: 's1',
    locationId: 'l1',
    lat: 37.5,
    lng: 127,
    address: '서울시 어딘가 12-3',
    detailAddress: '지하 1층',
    count: 2,
    createdAt: DateTime(2026, 8, 1),
    images: const [],
    ownerId: 'owner1',
    width: 10,
    height: 8,
    layout: {'lines': <Line>[], 'doors': <Offset>{}},
    approved: reviewStatus == ReviewStatus.approved,
    reviewStatus: reviewStatus,
    deleteRequested: deleteRequested,
  );
}

Zone _zone(String index) => Zone(
  index: index,
  x: 0,
  y: 0,
  angle: 0,
  width: 2,
  height: 3,
  price: 50000,
);

AppUser _user(String uid, String name) => AppUser(
  uid: uid,
  email: '$uid@example.com',
  nickName: name,
  photoURL: '',
  fcmToken: '',
  advertisement: false,
  userType: UserType.user,
);

Reservation _reservation({Status status = Status.waiting}) {
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
    monthlyPrice: 50000,
    months: 3,
    totalPrice: 150000,
  );
}

Usage _usage() {
  return Usage(
    id: 'us1',
    userId: 'u2',
    ownerId: 'owner1',
    storageId: 's1',
    containerIndex: 'B',
    startAt: DateTime(2026, 7, 1),
    endAt: DateTime(2026, 10, 1),
    createdAt: DateTime(2026, 6, 20),
    monthlyPrice: 40000,
  );
}

/// 목록 상태를 미리 채워 넣기 위한 가짜 notifier.
/// (진짜 build()는 빈 상태를 돌려주고 Firestore는 loadMyStorages에서만 만난다)
class _SeededNotifier extends MyStoragesNotifier {
  _SeededNotifier(this.seed);

  final MyStoragesState seed;

  @override
  MyStoragesState build() => seed;
}

Future<void> _pump(
  WidgetTester tester, {
  Storage? storage,
  List<Reservation> reservations = const [],
  List<Usage> usages = const [],
}) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final resolvedStorage = storage ?? _storage();
  final container = ProviderContainer(
    overrides: [
      myStoragesProvider.overrideWith(
        () => _SeededNotifier(
          MyStoragesState(
            storages: {'s1': resolvedStorage},
            reservationsByStorage: {'s1': reservations},
          ),
        ),
      ),
      storageZonesProvider(
        's1',
      ).overrideWith((ref) async => [_zone('A'), _zone('B')]),
      storageUsagesProvider(
        's1',
      ).overrideWith((ref) async => usages),
      userStreamProvider(
        'u1',
      ).overrideWith((ref) => Stream.value(_user('u1', '짐보관러'))),
      userStreamProvider(
        'u2',
      ).overrideWith((ref) => Stream.value(_user('u2', '장기이용자'))),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MyStorageDetailScreen(
          storageId: 's1',
          storage: resolvedStorage,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('운영 중 창고: 상태 배너와 비어 있는 구역이 보인다', (tester) async {
    await _pump(tester);

    expect(find.text('운영 중'), findsOneWidget);
    expect(find.text('구역별 현황'), findsOneWidget);
    // 두 구역 모두 아무 거래가 없다.
    expect(find.text('비어 있음'), findsNWidgets(2));
    expect(find.text('들어온 예약 요청이 없어요.'), findsOneWidget);
  });

  testWidgets('이용 중인 구역은 누가 언제까지 쓰는지 보인다', (tester) async {
    await _pump(tester, usages: [_usage()]);

    // B 구역 상태 칩
    expect(find.text('이용 중 · 2026.10.01까지'), findsOneWidget);
    // 이용 중인 계약 카드에 이용자 이름
    expect(find.text('이용 중인 계약'), findsOneWidget);
    expect(find.text('장기이용자님 · B 구역'), findsOneWidget);
  });

  testWidgets('대기 요청은 구역 칩과 예약 요청 목록에 함께 보인다', (tester) async {
    await _pump(tester, reservations: [_reservation()]);

    expect(find.text('요청 1건 대기'), findsOneWidget);
    expect(find.text('짐보관러님 · A 구역'), findsOneWidget);
    expect(find.text('대기중'), findsOneWidget);
  });

  testWidgets('확정 예약은 시작일과 함께 보인다', (tester) async {
    await _pump(
      tester,
      reservations: [_reservation(status: Status.approved)],
    );

    expect(find.text('예약 확정 · 2026.09.01 시작'), findsOneWidget);
    expect(find.text('승인됨'), findsOneWidget);
  });

  testWidgets('반려된 창고는 사유가 배너에 보인다', (tester) async {
    await _pump(
      tester,
      storage: Storage(
        id: 's1',
        locationId: 'l1',
        lat: 37.5,
        lng: 127,
        address: '서울시 어딘가 12-3',
        detailAddress: '지하 1층',
        count: 2,
        createdAt: DateTime(2026, 8, 1),
        images: const [],
        ownerId: 'owner1',
        width: 10,
        height: 8,
        layout: {'lines': <Line>[], 'doors': <Offset>{}},
        approved: false,
        reviewStatus: ReviewStatus.rejected,
        rejectReason: '사진이 흐려요',
      ),
    );

    expect(find.text('반려됨'), findsOneWidget);
    expect(find.textContaining('사진이 흐려요'), findsOneWidget);
  });

  testWidgets('삭제 요청 전에는 요청 버튼만 보인다', (tester) async {
    await _pump(tester);
    expect(find.text('삭제 요청'), findsOneWidget);
    expect(find.text('요청 취소'), findsNothing);
  });

  testWidgets('삭제 요청 후에는 검토 중 배너와 취소 버튼이 보인다', (tester) async {
    await _pump(tester, storage: _storage(deleteRequested: true));
    expect(find.text('삭제 요청 검토 중'), findsOneWidget);
    expect(find.text('요청 취소'), findsOneWidget);
  });

  testWidgets('삭제 요청 버튼은 바로 지우지 않고 안내 다이얼로그를 연다', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('삭제 요청'));
    await tester.pump();

    expect(find.text('창고 삭제를 요청할까요?'), findsOneWidget);
    expect(find.textContaining('운영자가 확인한 뒤'), findsOneWidget);
  });
}

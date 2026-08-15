import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/user.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/zone_provider.dart';
import 'package:jimiker/features/home/menu/find_storage/widgets/storage_bottom_sheet.dart';
import 'package:jimiker/services/auth_providers.dart';

Storage _storage({List<String> images = const []}) {
  return Storage(
    id: 's1',
    locationId: 'l1',
    lat: 37.5,
    lng: 127,
    address: '서울시 어딘가 12-3',
    detailAddress: '지하 1층',
    count: 2,
    createdAt: DateTime(2026, 8, 1),
    images: images,
    ownerId: 'owner1',
    width: 10,
    height: 8,
    layout: {'lines': <Line>[], 'doors': <Offset>{}},
    approved: true,
  );
}

Zone _zone(String index, int price, {double w = 2, double h = 3}) {
  return Zone(
    index: index,
    x: 0,
    y: 0,
    angle: 0,
    width: w,
    height: h,
    price: price,
  );
}

AppUser _owner() => AppUser(
  uid: 'owner1',
  email: 'owner@example.com',
  nickName: '창고왕',
  photoURL: '',
  fcmToken: '',
  advertisement: false,
  userType: UserType.user,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<Zone> zones,
  List<String> images = const [],
}) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      userStreamProvider(
        'owner1',
      ).overrideWith((ref) => Stream.value(_owner())),
    ],
  );
  addTearDown(container.dispose);
  container.read(zoneProvider.notifier).setZones(zones);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: StorageBottomSheet(
            imageUrl: images.isEmpty ? null : images.first,
            storage: _storage(images: images),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('최저가가 머리에 바로 보인다', (tester) async {
    await _pump(
      tester,
      zones: [_zone('A', 50000), _zone('B', 30000)],
    );

    // 구역마다 가격이 달라서 "부터"가 붙는다.
    expect(find.textContaining('월 30,000원'), findsWidgets);
    expect(find.textContaining('부터'), findsOneWidget);
  });

  testWidgets('요약 줄에 구역 수·건물 크기·면적이 나온다', (tester) async {
    await _pump(tester, zones: [_zone('A', 50000)]);

    expect(find.text('보관 구역'), findsOneWidget);
    expect(find.text('1개'), findsOneWidget);
    expect(find.text('10×8m'), findsOneWidget);
    // 10×8 = 80㎡ ≈ 24.2평
    expect(find.text('80㎡'), findsOneWidget);
    expect(find.textContaining('평'), findsWidgets);
  });

  testWidgets('구역 목록에서 가격을 비교할 수 있다', (tester) async {
    await _pump(
      tester,
      zones: [_zone('A', 50000), _zone('B', 30000, w: 1, h: 1)],
    );

    expect(find.text('A'), findsWidgets);
    expect(find.text('B'), findsWidgets);
    expect(find.textContaining('월 50,000원'), findsWidgets);
    // 크기가 달라도 ㎡당 가격으로 비교된다.
    expect(find.textContaining('㎡당'), findsWidgets);
  });

  testWidgets('주인 이름이 보인다', (tester) async {
    await _pump(tester, zones: [_zone('A', 50000)]);

    expect(find.text('창고왕님의 창고'), findsOneWidget);
  });

  testWidgets('구역을 고르기 전에는 안내가 뜬다', (tester) async {
    await _pump(tester, zones: [_zone('A', 50000)]);

    expect(
      find.textContaining('구역을 선택하면 날짜를 골라'),
      findsOneWidget,
    );
  });

  testWidgets('사진이 없으면 자리 표시를 보여준다', (tester) async {
    await _pump(tester, zones: [_zone('A', 50000)]);

    expect(find.text('등록된 사진이 없어요'), findsOneWidget);
  });
}

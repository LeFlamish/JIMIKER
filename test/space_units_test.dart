import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/features/draw/draw_provider.dart';
import 'package:jimiker/features/draw/zone_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/services/register_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/services/register_storage_validator.dart';
import 'package:jimiker/features/home/menu/register_storage/widgets/zone_form_dialog.dart';

Zone _zone({
  String index = 'A',
  double x = 0,
  double y = 0,
  double width = 2,
  double height = 3,
  int price = 50000,
}) {
  return Zone(
    index: index,
    x: x,
    y: y,
    angle: 0,
    width: width,
    height: height,
    price: price,
  );
}

void main() {
  group('space_units', () {
    test('딱 떨어지는 값은 소수점을 떼고 보여준다', () {
      expect(formatMeters(2.0), '2');
      expect(formatMeters(2.5), '2.5');
      expect(formatZoneSize(2.0, 3.5), '2×3.5m');
    });

    test('면적을 평과 같이 보여준다', () {
      // 3.3058㎡ = 1평
      expect(formatArea(6.0), '6.0㎡ (약 1.8평)');
      expect(formatArea(3.3058), contains('1.0평'));
    });

    test('㎡당 가격으로 크기 다른 구역을 비교할 수 있다', () {
      expect(formatPricePerSqm(50000, 6.0), '㎡당 8,333원');
      // 면적이 0이면 나누지 않는다.
      expect(formatPricePerSqm(50000, 0), '');
    });

    test('넓이 비유는 모든 구간에서 나온다', () {
      for (final area in [0.5, 1.5, 2.5, 5.0, 10.0, 20.0]) {
        expect(areaHint(area), isNotEmpty);
      }
    });
  });

  group('도면 축척', () {
    test('건물 크기를 정하면 외곽 네 벽이 실측대로 생긴다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(drawProvider.notifier).setBuildingSize(12, 8);
      final state = container.read(drawProvider);

      expect(state.width, 12);
      expect(state.height, 8);
      expect(state.lines, hasLength(4));

      // 외곽 벽 길이의 합 = 둘레
      final total = state.lines.fold<double>(
        0,
        (sum, line) => sum + (line.end - line.start).distance,
      );
      expect(total, closeTo(2 * (12 + 8), 0.001));
    });

    test('이미 벽이 있으면 외곽을 다시 만들지 않는다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(drawProvider.notifier);
      notifier.setBuildingSize(12, 8);
      notifier.setBuildingSize(12, 8);

      expect(container.read(drawProvider).lines, hasLength(4));
    });
  });

  group('등록 검증: 도면과 구역의 교차 확인', () {
    RegisterStorageValidationResult validate({
      required double buildingW,
      required double buildingH,
      required List<Zone> zones,
    }) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(drawProvider.notifier)
          .setBuildingSize(buildingW, buildingH);

      return RegisterStorageValidator.validate(
        registerData: RegisterData(),
        drawState: container.read(drawProvider),
        zones: zones,
        detailAddress: '지하 1층',
      );
    }

    test('건물보다 큰 구역을 잡아낸다', () {
      final result = validate(
        buildingW: 5,
        buildingH: 5,
        zones: [_zone(width: 6, height: 2)],
      );
      expect(result.message, contains('건물보다 큰 구역'));
    });

    test('구역 면적 합이 건물을 넘으면 잡아낸다', () {
      // 각각은 건물 안에 들어가지만 합치면 25㎡ 건물에 32㎡.
      final result = validate(
        buildingW: 5,
        buildingH: 5,
        zones: [
          _zone(index: 'A', width: 4, height: 4),
          _zone(index: 'B', width: 4, height: 4),
        ],
      );
      expect(result.message, contains('넘어요'));
    });

    test('정상 구성은 통과한다 (주소·사진 외 항목)', () {
      final result = validate(
        buildingW: 10,
        buildingH: 8,
        zones: [
          _zone(index: 'A'),
          _zone(index: 'B', x: 3),
        ],
      );
      // 사진·주소 오류만 남아야 한다 (이 테스트는 도면 검증만 본다).
      expect(result.message, isNot(contains('건물')));
      expect(result.message, isNot(contains('구역 면적')));
    });
  });

  group('구역 이름', () {
    test('중간 구역을 지워도 이름이 겹치지 않는다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(zoneProvider.notifier);

      notifier.addZone(_zone(index: 'A'));
      notifier.addZone(_zone(index: 'B'));
      notifier.addZone(_zone(index: 'C'));
      notifier.removeZone('B');

      // 예전 코드는 개수(2) 기반이라 'C'를 또 내놓았다.
      expect(notifier.nextIndex(), 'B');
    });
  });

  group('ZoneFormDialog', () {
    testWidgets('크기를 입력하면 면적·평·비유가 실시간으로 뜬다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: ZoneFormDialog(index: 'A')),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '가로 길이 (m)'),
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '세로 길이 (m)'),
        '3',
      );
      await tester.pump();

      expect(find.text('6.0㎡ (약 1.8평)'), findsOneWidget);

      // 임대료까지 넣으면 ㎡당 가격도 나온다.
      await tester.enterText(
        find.widgetWithText(TextFormField, '월 임대료 (원)'),
        '60000',
      );
      await tester.pump();

      expect(find.text('㎡당 10,000원'), findsOneWidget);
    });

    testWidgets('60m를 넘는 크기는 막는다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: ZoneFormDialog(index: 'A')),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '가로 길이 (m)'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '세로 길이 (m)'),
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '월 임대료 (원)'),
        '10000',
      );
      await tester.tap(find.text('추가'));
      await tester.pump();

      expect(find.text('60m 이하로 입력해주세요.'), findsOneWidget);
    });
  });
}

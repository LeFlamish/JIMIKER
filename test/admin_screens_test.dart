import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override 타입은 misc.dart에서 노출된다.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/user.dart';
import 'package:jimiker/features/admin/screens/admin_home_screen.dart';
import 'package:jimiker/features/admin/screens/admin_users_screen.dart';
import 'package:jimiker/features/admin/screens/storage_review_screen.dart';
import 'package:jimiker/features/admin/services/admin_providers.dart';
import 'package:jimiker/services/storage_zones_provider.dart';

AppUser _user({
  String uid = 'u1',
  String nickName = '홍길동',
  bool suspended = false,
  UserType type = UserType.user,
  String suspendReason = '',
}) {
  return AppUser(
    uid: uid,
    email: '$uid@example.com',
    nickName: nickName,
    photoURL: '',
    fcmToken: 'token',
    advertisement: false,
    userType: type,
    suspended: suspended,
    suspendReason: suspendReason,
    createdAt: DateTime(2026, 3, 1),
  );
}

Future<void> _pump(WidgetTester tester, Widget child,
    {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Storage.reviewStatus', () {
    test('예전 문서는 approved를 보고 상태를 정한다', () {
      // reviewStatus 필드가 없던 시절 문서와의 호환.
      expect(
        Storage(
          locationId: 'l',
          lat: 0,
          lng: 0,
          address: '',
          detailAddress: '',
          count: 0,
          createdAt: DateTime(2026),
          images: const [],
          ownerId: 'o',
          width: 0,
          height: 0,
          layout: const {},
          approved: true,
        ).reviewStatus,
        // 생성자 기본값은 pending이지만 fromDoc에서 approved를 보고 바꾼다.
        ReviewStatus.pending,
      );
    });
  });

  group('AdminHomeScreen', () {
    testWidgets('처리할 게 남아 있으면 눈에 띄게 알린다', (tester) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        overrides: [
          adminSummaryProvider.overrideWith(
            (ref) async => const AdminSummary(
              pendingStorages: 3,
              waitingReservations: 2,
              activeUsages: 5,
              totalUsers: 40,
            ),
          ),
        ],
      );

      expect(find.text('승인 대기 3건'), findsOneWidget);
      expect(find.text('창고 승인'), findsOneWidget);
      expect(find.text('사용자 관리'), findsOneWidget);
      expect(find.text('거래 현황'), findsOneWidget);
      expect(find.text('처리 기록'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('이관이 밀린 이용 건을 경고한다', (tester) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        overrides: [
          adminSummaryProvider.overrideWith(
            (ref) async =>
                const AdminSummary(activeUsages: 4, overdueUsages: 2),
          ),
        ],
      );

      expect(find.text('기간이 지난 이용 2건'), findsOneWidget);
      expect(
        find.textContaining('이관 함수를 확인해주세요'),
        findsOneWidget,
      );
    });

    testWidgets('처리할 게 없으면 경고를 띄우지 않는다', (tester) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        overrides: [
          adminSummaryProvider.overrideWith(
            (ref) async => const AdminSummary(totalUsers: 10),
          ),
        ],
      );

      expect(find.textContaining('승인 대기 '), findsNothing);
      expect(find.textContaining('기간이 지난 이용'), findsNothing);
    });
  });

  group('StorageReviewDetailScreen 버튼 상태', () {
    // 지금 상태에서 의미 없는 동작은 아예 보이지 않아야 한다.
    Storage storage(ReviewStatus status) => Storage(
      id: 's1',
      locationId: 'l1',
      lat: 37.5,
      lng: 127,
      address: '서울시 어딘가',
      detailAddress: '지하 1층',
      count: 2,
      createdAt: DateTime(2026, 5, 1),
      images: const [],
      ownerId: 'owner',
      width: 300,
      height: 240,
      layout: const {},
      approved: status == ReviewStatus.approved,
      reviewStatus: status,
    );

    Future<void> pumpDetail(
      WidgetTester tester,
      ReviewStatus status, {
      StorageTradeImpact impact = const StorageTradeImpact(
        activeUsages: 0,
        openReservations: 0,
      ),
    }) async {
      await _pump(
        tester,
        StorageReviewDetailScreen(storage: storage(status)),
        overrides: [
          storageZonesProvider('s1').overrideWith((ref) async => []),
          storageTradeImpactProvider('s1').overrideWith(
            (ref) async => impact,
          ),
        ],
      );
    }

    testWidgets('대기중이면 승인과 반려 둘 다 나온다', (tester) async {
      await pumpDetail(tester, ReviewStatus.pending);

      expect(find.widgetWithText(ElevatedButton, '승인'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '반려'), findsOneWidget);
    });

    testWidgets('이미 승인된 창고에는 승인 버튼이 없다', (tester) async {
      await pumpDetail(tester, ReviewStatus.approved);

      expect(find.textContaining('승인으로 변경'), findsNothing);
      expect(find.text('승인'), findsNothing);
      // 반려로 되돌리는 것은 가능해야 한다.
      expect(find.text('반려로 변경'), findsOneWidget);
    });

    testWidgets('반려된 창고에는 반려 버튼이 없다', (tester) async {
      await pumpDetail(tester, ReviewStatus.rejected);

      expect(find.textContaining('반려로 변경'), findsNothing);
      expect(find.text('승인으로 변경'), findsOneWidget);
    });
  });

  group('반려가 건드리는 범위', () {
    Storage approvedStorage() => Storage(
      id: 's1',
      locationId: 'l1',
      lat: 37.5,
      lng: 127,
      address: '서울시 어딘가',
      detailAddress: '지하 1층',
      count: 2,
      createdAt: DateTime(2026, 5, 1),
      images: const [],
      ownerId: 'owner',
      width: 300,
      height: 240,
      layout: const {},
      approved: true,
      reviewStatus: ReviewStatus.approved,
    );

    Future<void> pumpWithImpact(
      WidgetTester tester,
      StorageTradeImpact impact,
    ) async {
      await _pump(
        tester,
        StorageReviewDetailScreen(storage: approvedStorage()),
        overrides: [
          storageZonesProvider('s1').overrideWith((ref) async => []),
          storageTradeImpactProvider('s1').overrideWith(
            (ref) async => impact,
          ),
        ],
      );
    }

    testWidgets('진행 중인 거래를 반려 전에 보여준다', (tester) async {
      await pumpWithImpact(
        tester,
        const StorageTradeImpact(activeUsages: 2, openReservations: 3),
      );

      expect(find.text('진행 중인 거래'), findsOneWidget);
      expect(find.text('2건 (반려해도 유지)'), findsOneWidget);
      expect(find.text('3건 (반려하면 취소)'), findsOneWidget);
    });

    testWidgets('걸린 거래가 없으면 카드를 띄우지 않는다', (tester) async {
      await pumpWithImpact(
        tester,
        const StorageTradeImpact(activeUsages: 0, openReservations: 0),
      );

      expect(find.text('진행 중인 거래'), findsNothing);
    });

    testWidgets('반려 사유를 물을 때 무엇이 어떻게 되는지 알려준다', (tester) async {
      await pumpWithImpact(
        tester,
        const StorageTradeImpact(activeUsages: 1, openReservations: 2),
      );

      await tester.tap(find.text('반려로 변경'));
      await tester.pumpAndSettle();

      // 이용 중은 유지, 예약은 취소 — 둘을 구분해서 안내해야 한다.
      expect(
        find.textContaining('이용 중 1건은 그대로 둡니다'),
        findsWidgets,
      );
      expect(
        find.textContaining('예약 2건은 취소되고'),
        findsWidgets,
      );
    });

    testWidgets('반려된 창고를 되살릴 때 예약은 안 돌아온다고 알린다', (tester) async {
      await _pump(
        tester,
        StorageReviewDetailScreen(
          storage: Storage(
            id: 's1',
            locationId: 'l1',
            lat: 37.5,
            lng: 127,
            address: '서울시 어딘가',
            detailAddress: '지하 1층',
            count: 2,
            createdAt: DateTime(2026, 5, 1),
            images: const [],
            ownerId: 'owner',
            width: 300,
            height: 240,
            layout: const {},
            approved: false,
            reviewStatus: ReviewStatus.rejected,
          ),
        ),
        overrides: [
          storageZonesProvider('s1').overrideWith((ref) async => []),
          storageTradeImpactProvider('s1').overrideWith(
            (ref) async => const StorageTradeImpact(
              activeUsages: 0,
              openReservations: 0,
            ),
          ),
        ],
      );

      await tester.tap(find.text('승인으로 변경'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('취소된 예약은 되살아나지 않아요'),
        findsOneWidget,
      );
    });
  });

  group('AdminUserDetailScreen', () {
    testWidgets('정상 계정은 이용 정지 버튼을 보여준다', (tester) async {
      await _pump(
        tester,
        AdminUserDetailScreen(user: _user()),
        overrides: [
          userActivityProvider('u1').overrideWith(
            (ref) async => const UserActivity(
              storageCount: 1,
              reservationCount: 0,
              usageCount: 0,
              endedCount: 3,
            ),
          ),
        ],
      );

      expect(find.text('정상 이용 중'), findsOneWidget);
      expect(find.text('이용 정지'), findsOneWidget);
      expect(find.text('3건'), findsOneWidget);
    });

    testWidgets('정지된 계정은 사유와 해제 버튼을 보여준다', (tester) async {
      await _pump(
        tester,
        AdminUserDetailScreen(
          user: _user(suspended: true, suspendReason: '허위 매물'),
        ),
        overrides: [
          userActivityProvider('u1').overrideWith(
            (ref) async => const UserActivity(
              storageCount: 0,
              reservationCount: 0,
              usageCount: 0,
              endedCount: 0,
            ),
          ),
        ],
      );

      expect(find.text('이용 정지됨'), findsOneWidget);
      expect(find.text('허위 매물'), findsOneWidget);
      expect(find.text('정지 해제'), findsOneWidget);
    });

    testWidgets('관리자 계정은 앱에서 손댈 수 없다고 안내한다', (tester) async {
      await _pump(
        tester,
        AdminUserDetailScreen(
          user: _user(type: UserType.manager),
        ),
        overrides: [
          userActivityProvider('u1').overrideWith(
            (ref) async => const UserActivity(
              storageCount: 0,
              reservationCount: 0,
              usageCount: 0,
              endedCount: 0,
            ),
          ),
        ],
      );

      expect(find.text('관리자 계정'), findsOneWidget);
      expect(find.text('이용 정지'), findsNothing);
      expect(
        find.textContaining('Firebase 콘솔에서 해주세요'),
        findsOneWidget,
      );
    });

    testWidgets('진행 중 거래가 있으면 정지 전에 경고한다', (tester) async {
      await _pump(
        tester,
        AdminUserDetailScreen(user: _user()),
        overrides: [
          userActivityProvider('u1').overrideWith(
            (ref) async => const UserActivity(
              storageCount: 2,
              reservationCount: 1,
              usageCount: 1,
              endedCount: 0,
            ),
          ),
        ],
      );

      expect(
        find.textContaining('상대방도 영향을 받습니다'),
        findsOneWidget,
      );
    });

    testWidgets('정지를 누르면 사유 입력을 요구한다', (tester) async {
      await _pump(
        tester,
        AdminUserDetailScreen(user: _user()),
        overrides: [
          userActivityProvider('u1').overrideWith(
            (ref) async => const UserActivity(
              storageCount: 0,
              reservationCount: 0,
              usageCount: 0,
              endedCount: 0,
            ),
          ),
        ],
      );

      await tester.tap(find.text('이용 정지'));
      await tester.pumpAndSettle();

      expect(find.text('이용 정지'), findsWidgets);
      expect(find.textContaining('채팅은 그대로 열어둡니다'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

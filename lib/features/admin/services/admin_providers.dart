import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/reservation.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/usage.dart';
import 'package:jimiker/data/models/user.dart';
import 'package:jimiker/services/auth_providers.dart';

/// 관리자 조치는 전부 Cloud Functions를 거친다.
///
/// 보안 규칙에는 매니저 쓰기 권한을 넣지 않았기 때문에, 앱을 고쳐도
/// 여기를 우회해서 승인할 수 없다. 서버가 호출자 등급을 다시 확인한다.
final adminActionsProvider = Provider<AdminActions>((ref) {
  return AdminActions(
    FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
  );
});

class AdminActions {
  const AdminActions(this._functions);

  final FirebaseFunctions _functions;

  Future<void> approveStorage(String storageId) async {
    await _functions.httpsCallable('approveStorage').call({
      'storageId': storageId,
    });
  }

  /// 창고를 반려한다. 서버가 예약까지 정리한 뒤 실제 건수를 돌려준다.
  Future<RejectResult> rejectStorage({
    required String storageId,
    required String reason,
  }) async {
    final result = await _functions.httpsCallable('rejectStorage').call({
      'storageId': storageId,
      'reason': reason,
    });

    // 예전 버전 함수는 {ok: true}만 돌려준다. 그때는 0으로 둔다.
    final data = result.data;
    int read(String key) =>
        data is Map ? (data[key] as num?)?.toInt() ?? 0 : 0;

    return RejectResult(
      cancelledReservations: read('cancelledReservations'),
      keptUsages: read('keptUsages'),
    );
  }

  Future<void> setUserSuspended({
    required String uid,
    required bool suspended,
    String reason = '',
  }) async {
    await _functions.httpsCallable('setUserSuspended').call({
      'uid': uid,
      'suspended': suspended,
      'reason': reason,
    });
  }
}

/// 반려가 실제로 정리한 것들.
class RejectResult {
  const RejectResult({
    required this.cancelledReservations,
    required this.keptUsages,
  });

  /// 함께 취소된 예약 수
  final int cancelledReservations;

  /// 손대지 않고 그대로 둔 이용 중 건수
  final int keptUsages;
}

/// 심사 상태별 창고 목록.
///
/// 예전 문서에는 reviewStatus가 없어서 쿼리로 거르면 빠진다.
/// 전부 받아서 모델이 판단한 상태로 나눈다. (관리자만 쓰는 화면이라 감당 가능)
final storagesByReviewProvider = StreamProvider.autoDispose
    .family<List<Storage>, ReviewStatus>((ref, status) {
      return ref
          .watch(firestoreProvider)
          .collection('storages')
          .snapshots()
          .map((snapshot) {
            final storages =
                snapshot.docs
                    .map(Storage.fromDoc)
                    .where(
                      (storage) =>
                          !storage.deleted &&
                          storage.reviewStatus == status,
                    )
                    .toList()
                  // 오래 기다린 건이 위로 오게
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return storages;
          });
    });

/// 관리자 홈에 띄울 요약 숫자
class AdminSummary {
  const AdminSummary({
    this.pendingStorages = 0,
    this.waitingReservations = 0,
    this.activeUsages = 0,
    this.overdueUsages = 0,
    this.totalUsers = 0,
    this.suspendedUsers = 0,
  });

  final int pendingStorages;
  final int waitingReservations;
  final int activeUsages;

  /// 종료일이 지났는데 아직 이용 내역으로 안 넘어간 건.
  /// 0이 아니면 이관 함수가 멈춰 있다는 뜻이다.
  final int overdueUsages;
  final int totalUsers;
  final int suspendedUsers;
}

final adminSummaryProvider = FutureProvider.autoDispose<AdminSummary>((
  ref,
) async {
  final firestore = ref.watch(firestoreProvider);
  final now = Timestamp.now();

  final results = await Future.wait([
    firestore.collection('storages').get(),
    firestore
        .collection('reservations')
        .where('status', isEqualTo: 'waiting')
        .get(),
    firestore.collection('usages').get(),
    firestore.collection('users').get(),
  ]);

  final storages = results[0].docs
      .map(Storage.fromDoc)
      .where((storage) => !storage.deleted);
  final usages = results[2].docs.map(Usage.fromDoc);
  final users = results[3].docs.map(AppUser.fromDoc);

  return AdminSummary(
    pendingStorages: storages
        .where((s) => s.reviewStatus == ReviewStatus.pending)
        .length,
    waitingReservations: results[1].docs.length,
    activeUsages: usages.length,
    overdueUsages: usages
        .where((usage) => usage.endAt.isBefore(now.toDate()))
        .length,
    totalUsers: users.length,
    suspendedUsers: users.where((user) => user.suspended).length,
  );
});

/// 창고 하나를 반려하면 무엇이 영향을 받는지.
///
/// 이용 중인 건은 그대로 두고 예약만 취소하기 때문에, 관리자가 누르기 전에
/// "몇 명이 짐을 넣어둔 상태인지"를 보고 판단할 수 있어야 한다.
class StorageTradeImpact {
  const StorageTradeImpact({
    required this.activeUsages,
    required this.openReservations,
  });

  /// 이용 중 — 반려해도 기간이 끝날 때까지 유지된다.
  final int activeUsages;

  /// 아직 시작 전인 예약(대기 + 확정) — 반려하면 취소된다.
  final int openReservations;

  bool get isEmpty => activeUsages == 0 && openReservations == 0;
}

final storageTradeImpactProvider = FutureProvider.autoDispose
    .family<StorageTradeImpact, String>((ref, storageId) async {
      if (storageId.isEmpty) {
        return const StorageTradeImpact(
          activeUsages: 0,
          openReservations: 0,
        );
      }

      final firestore = ref.watch(firestoreProvider);
      final results = await Future.wait([
        firestore
            .collection('usages')
            .where('storageId', isEqualTo: storageId)
            .get(),
        firestore
            .collection('reservations')
            .where('storageId', isEqualTo: storageId)
            .get(),
      ]);

      return StorageTradeImpact(
        activeUsages: results[0].docs.length,
        // 이미 거절된 건은 취소할 것도 없다.
        openReservations: results[1].docs
            .map(Reservation.fromDoc)
            .where((r) => r.status != Status.rejected)
            .length,
      );
    });

/// 사용자 목록. 가입일 최신순.
final adminUsersProvider = StreamProvider.autoDispose<List<AppUser>>((
  ref,
) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .snapshots()
      .map((snapshot) {
        final users = snapshot.docs.map(AppUser.fromDoc).toList()
          ..sort((a, b) {
            final aTime =
                a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        return users;
      });
});

/// 한 사용자의 활동 요약 (상세 화면용)
class UserActivity {
  const UserActivity({
    required this.storageCount,
    required this.reservationCount,
    required this.usageCount,
    required this.endedCount,
  });

  final int storageCount;
  final int reservationCount;
  final int usageCount;
  final int endedCount;

  bool get hasOngoing => reservationCount > 0 || usageCount > 0;
}

final userActivityProvider = FutureProvider.autoDispose
    .family<UserActivity, String>((ref, uid) async {
      final firestore = ref.watch(firestoreProvider);

      final results = await Future.wait([
        firestore
            .collection('storages')
            .where('ownerId', isEqualTo: uid)
            .get(),
        firestore
            .collection('reservations')
            .where('userId', isEqualTo: uid)
            .get(),
        firestore
            .collection('usages')
            .where('userId', isEqualTo: uid)
            .get(),
        firestore
            .collection('endeds')
            .where('userId', isEqualTo: uid)
            .get(),
      ]);

      return UserActivity(
        storageCount: results[0].docs
            .map(Storage.fromDoc)
            .where((storage) => !storage.deleted)
            .length,
        reservationCount: results[1].docs.length,
        usageCount: results[2].docs.length,
        endedCount: results[3].docs.length,
      );
    });

/// 거래 현황 화면에서 보는 세 가지
enum TradeKind { reservation, usage, ended }

final adminReservationsProvider =
    StreamProvider.autoDispose<List<Reservation>>((ref) {
      return ref
          .watch(firestoreProvider)
          .collection('reservations')
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(Reservation.fromDoc).toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          );
    });

final adminUsagesProvider = StreamProvider.autoDispose
    .family<List<Usage>, TradeKind>((ref, kind) {
      final collection = kind == TradeKind.usage ? 'usages' : 'endeds';
      return ref
          .watch(firestoreProvider)
          .collection(collection)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(Usage.fromDoc).toList()
              ..sort((a, b) => b.endAt.compareTo(a.endAt)),
          );
    });

/// 관리자 처리 기록
class AdminLog {
  const AdminLog({
    required this.id,
    required this.actorUid,
    required this.action,
    required this.targetId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String actorUid;
  final String action;
  final String targetId;
  final String reason;
  final DateTime? createdAt;

  String get actionLabel => switch (action) {
    'approveStorage' => '창고 승인',
    'rejectStorage' => '창고 반려',
    'suspendUser' => '이용 정지',
    'unsuspendUser' => '정지 해제',
    _ => action,
  };

  factory AdminLog.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AdminLog(
      id: doc.id,
      actorUid: data['actorUid']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      targetId: data['targetId']?.toString() ?? '',
      reason: data['reason']?.toString() ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate().toLocal(),
    );
  }
}

final adminLogsProvider = StreamProvider.autoDispose<List<AdminLog>>((
  ref,
) {
  return ref
      .watch(firestoreProvider)
      .collection('admin_logs')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AdminLog.fromDoc).toList());
});

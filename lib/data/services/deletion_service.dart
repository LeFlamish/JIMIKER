import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// 삭제 요청을 막아야 할 때 던지는 예외. message를 그대로 사용자에게 보여준다.
class DeletionBlocked implements Exception {
  const DeletionBlocked(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 창고/계정을 지울 때 Firestore와 Storage를 함께 정리한다.
///
/// ## 왜 전부 지우지 않는가
///
/// 창고 문서는 예약(reservations)·이용중(usages)·이용내역(endeds)이 참조한다.
/// 그냥 지워버리면 "내가 작년에 어디를 썼는지"가 통째로 사라지고, 상대방(주인/이용자)
/// 화면도 같이 깨진다. 거래 기록은 양쪽 모두에게 남아 있어야 하는 정보다.
///
/// 그래서 두 갈래로 처리한다.
///  - 참조가 하나도 없는 창고  → 완전 삭제 (문서 + 구역 + Storage 이미지)
///  - 참조가 남아 있는 창고    → 소프트 삭제 (deleted 표시, 목록/지도에서 감춤)
///
/// 계정은 개인정보만 지우고 거래 기록은 남긴다. 상대방 입장에서 "탈퇴한 사용자"와
/// 거래한 기록은 그대로 보여야 하기 때문이다.
class DeletionService {
  const DeletionService({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _storage = storage,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  /// 탈퇴한 계정에 남길 이름
  static const String withdrawnNickName = '탈퇴한 사용자';

  // ------------------------------------------------------------ 창고 삭제

  /// 창고를 삭제한다. 완전히 지웠으면 true, 기록 때문에 보관 처리했으면 false.
  ///
  /// 진행 중인 예약이나 이용이 있으면 [DeletionBlocked]를 던진다.
  Future<bool> deleteStorage(String storageId) async {
    if (storageId.isEmpty) {
      throw const DeletionBlocked('창고 정보가 올바르지 않아요.');
    }

    final blockers = await _countActiveBlockers(storageId);
    if (blockers > 0) {
      throw const DeletionBlocked(
        '아직 이용 중이거나 예약된 창고예요.\n'
        '예약을 정리한 뒤 다시 시도해주세요.',
      );
    }

    final hasHistory = await _hasAnyHistory(storageId);
    final storageRef = _firestore.collection('storages').doc(storageId);

    if (hasHistory) {
      // 지난 이용 내역이 참조 중 → 문서는 남기고 목록에서만 감춘다.
      await storageRef.set({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return false;
    }

    // 아무도 참조하지 않는 창고 → 사진까지 완전히 정리한다.
    final snapshot = await storageRef.get();
    final images =
        (snapshot.data()?['images'] as List<dynamic>?)
            ?.cast<String>() ??
        const [];

    await _deleteSubcollection(storageRef.collection('zones'));
    await storageRef.delete();
    await _deleteImages(images);
    return true;
  }

  /// 해당 창고를 아직 붙잡고 있는 예약/이용 건수.
  /// (거절된 예약은 이미 끝난 건이라 세지 않는다.)
  Future<int> _countActiveBlockers(String storageId) async {
    final results = await Future.wait([
      _firestore
          .collection('reservations')
          .where('storageId', isEqualTo: storageId)
          .get(),
      _firestore
          .collection('usages')
          .where('storageId', isEqualTo: storageId)
          .get(),
    ]);

    final liveReservations = results[0].docs.where(
      (doc) => doc.data()['status'] != 'rejected',
    );

    return liveReservations.length + results[1].docs.length;
  }

  /// 지난 기록(종료된 이용, 거절된 예약)이 이 창고를 참조하는지.
  Future<bool> _hasAnyHistory(String storageId) async {
    final results = await Future.wait([
      _firestore
          .collection('endeds')
          .where('storageId', isEqualTo: storageId)
          .limit(1)
          .get(),
      _firestore
          .collection('reservations')
          .where('storageId', isEqualTo: storageId)
          .limit(1)
          .get(),
    ]);

    return results.any((snapshot) => snapshot.docs.isNotEmpty);
  }

  // ------------------------------------------------------------ 계정 삭제

  /// 회원 탈퇴.
  ///
  /// 1. 이용 중인 창고가 있으면 막는다.
  /// 2. 내가 등록한 창고를 모두 정리한다.
  /// 3. users 문서에서 개인정보를 지우고 프로필 사진도 삭제한다.
  /// 4. Firebase Auth 계정을 삭제한다.
  ///
  /// 예약/이용 기록은 상대방에게도 필요한 정보라 남긴다.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const DeletionBlocked('로그인이 필요합니다.');
    }
    final uid = user.uid;

    await _ensureNoActiveTrades(uid);
    await _deleteMyStorages(uid);
    await _anonymizeUserDoc(uid);

    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw const DeletionBlocked(
          '보안을 위해 다시 로그인한 뒤 탈퇴할 수 있어요.\n'
          '로그아웃 후 다시 로그인해주세요.',
        );
      }
      rethrow;
    }
  }

  /// 이용 중이거나 대기/확정된 예약이 남아 있으면 탈퇴를 막는다.
  /// (빌린 쪽이든 빌려준 쪽이든 상대가 있는 거래는 정리하고 나가야 한다.)
  Future<void> _ensureNoActiveTrades(String uid) async {
    final results = await Future.wait([
      _firestore
          .collection('usages')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get(),
      _firestore
          .collection('usages')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get(),
      _firestore
          .collection('reservations')
          .where('userId', isEqualTo: uid)
          .get(),
      _firestore
          .collection('reservations')
          .where('ownerId', isEqualTo: uid)
          .get(),
    ]);

    if (results[0].docs.isNotEmpty || results[1].docs.isNotEmpty) {
      throw const DeletionBlocked(
        '아직 이용 중인 창고가 있어요.\n이용을 마친 뒤 탈퇴할 수 있어요.',
      );
    }

    final pendingReservations = [
      ...results[2].docs,
      ...results[3].docs,
    ].where((doc) => doc.data()['status'] != 'rejected');

    if (pendingReservations.isNotEmpty) {
      throw const DeletionBlocked(
        '처리되지 않은 예약이 있어요.\n예약을 정리한 뒤 탈퇴할 수 있어요.',
      );
    }
  }

  Future<void> _deleteMyStorages(String uid) async {
    final snapshot = await _firestore
        .collection('storages')
        .where('ownerId', isEqualTo: uid)
        .get();

    for (final doc in snapshot.docs) {
      try {
        await deleteStorage(doc.id);
      } on DeletionBlocked {
        // 위에서 이미 활성 거래를 걸렀으므로 여기 오면 남겨두고 넘어간다.
        debugPrint('Skipped storage ${doc.id} while deleting account');
      }
    }
  }

  /// users 문서에서 개인정보만 비운다. 문서 자체는 남겨서
  /// 상대방 화면에 "탈퇴한 사용자"로 보이게 한다.
  Future<void> _anonymizeUserDoc(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final snapshot = await userRef.get();
    final photoURL = snapshot.data()?['photoURL']?.toString();

    await userRef.set({
      'email': '',
      'nickName': withdrawnNickName,
      'photoURL': '',
      'fcmToken': '',
      'advertisement': false,
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (photoURL != null && photoURL.isNotEmpty) {
      await _deleteImages([photoURL]);
    }
  }

  // -------------------------------------------------------------- 공통

  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// 다운로드 URL로 Storage 파일을 지운다.
  ///
  /// 이미 지워졌거나 URL이 깨져 있어도 삭제 자체는 계속 진행해야 하므로
  /// 개별 실패는 로그만 남기고 넘어간다.
  Future<void> _deleteImages(List<String> downloadUrls) async {
    for (final url in downloadUrls) {
      if (url.isEmpty) continue;
      try {
        await _storage.refFromURL(url).delete();
      } catch (error) {
        debugPrint('Failed to delete storage file: $url ($error)');
      }
    }
  }
}

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

/// 계정을 지울 때 Firestore와 Storage를 함께 정리한다.
///
/// ## 창고는 여기서 "완전히" 지우지 않는다
///
/// 창고 문서는 예약(reservations)·이용중(usages)·이용내역(endeds)이 참조하고,
/// 보안 규칙도 클라이언트의 storages delete를 막는다. 창고를 실제로 지우는 건
/// 운영자 승인 절차(approveStorageDeletion 함수)뿐이다.
/// 탈퇴할 때는 내 창고를 deleted 표시(소프트 삭제)로 내리기만 한다.
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

  /// 내 창고를 전부 목록·지도에서 내린다. (소프트 삭제)
  ///
  /// 문서 자체는 남는다. 지난 거래 기록이 참조할 수 있고,
  /// 완전 삭제는 운영자 승인 절차(서버)만 할 수 있어서다.
  Future<void> _deleteMyStorages(String uid) async {
    final snapshot = await _firestore
        .collection('storages')
        .where('ownerId', isEqualTo: uid)
        .get();

    for (final doc in snapshot.docs) {
      try {
        await doc.reference.set({
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deleteRequested': false,
        }, SetOptions(merge: true));
      } catch (error) {
        // 하나가 막혀도 탈퇴 자체는 계속 진행한다.
        debugPrint('Failed to retire storage ${doc.id}: $error');
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

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/dataSource/user_source.dart';
import '../data/models/user.dart';
import '../data/repository/user_repository.dart';
import '../data/services/deletion_service.dart';
import '../features/auth/sign_in_screen.dart';

/// FirebaseAuth 인스턴스
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Firebase 인증 상태 스트림 (로그인/로그아웃 변화를 듣는 용도)
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  return auth.authStateChanges();
});

// 1) Firestore Provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// 창고/계정 삭제 시 Firestore + Storage 정리
final deletionServiceProvider = Provider<DeletionService>((ref) {
  return DeletionService(
    firestore: ref.read(firestoreProvider),
    storage: ref.read(firebaseStorageProvider),
    auth: ref.read(firebaseAuthProvider),
  );
});

// 2) DataSource Provider
final userDataSourceProvider = Provider<UserDataSource>((ref) {
  return UserDataSourceImpl(ref.read(firestoreProvider));
});

// 3) Repository Provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(ref.read(userDataSourceProvider));
});

// 4) uid로 AppUser 실시간 스트림 불러오기 (family)
final userStreamProvider = StreamProvider.family
    .autoDispose<AppUser?, String>((ref, uid) {
      final repo = ref.read(userRepositoryProvider);
      return repo.watchUser(uid); // ✅ Stream<AppUser?> 그대로 반환
    });

/// 실제 로그인/로그아웃 액션 담당 클래스
/// 로그인 창 Consumer로 사용
/// AuthController controller로 선언(ref 인자로 넣어주고)
/// controller.signInWithGoogle() 호출
/// 로그아웃 시 controller.signOut() 호출
class AuthController extends Notifier<AppUser?> {
  Future<AppUser?>? _meFuture;
  String? _cachedUid;

  @override
  AppUser? build() => null; // 초기 me

  AppUser? get me => state;

  void _clearCache() {
    state = null; // ✅ notifier 발생
    _meFuture = null;
    _cachedUid = null;
  }

  Future<void> upsertFcmTokenToUserDoc(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // 로그인 안됐으면 스킵

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);

    await userRef.set({'fcmToken': token}, SetOptions(merge: true));
  }

  StreamSubscription<String>? _tokenSub;

  Future<void> initFcmTokenSync() async {
    // 1) 초기 토큰
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await upsertFcmTokenToUserDoc(token);
    }

    // 2) 토큰 갱신 리스너
    _tokenSub?.cancel();
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      await upsertFcmTokenToUserDoc(newToken);
    });
  }

  Future<void> disposeFcmTokenSync() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }

  Future<AppUser?> _ensureAndFetchMe(User fbUser) {
    // 계정 변경 시 캐시 초기화
    if (_cachedUid != null && _cachedUid != fbUser.uid) {
      _clearCache();
    }
    _cachedUid ??= fbUser.uid;

    // 캐시 있으면 그대로
    if (state != null) return Future.value(state);

    // 로딩 중이면 공유
    if (_meFuture != null) return _meFuture!;

    final repo = ref.read(userRepositoryProvider);

    _meFuture =
        () async {
          var userDoc = await repo.getUser(fbUser.uid);

          if (userDoc == null) {
            final docRef = FirebaseFirestore.instance
                .collection('users')
                .doc(fbUser.uid);

            final appUser = AppUser(
              uid: fbUser.uid,
              email: fbUser.email ?? '',
              nickName: fbUser.displayName ?? '',
              photoURL: '',
              fcmToken: '',
              advertisement: false,
              userType: UserType.user,
            );

            await docRef.set({
              ...appUser.toMap(),
              'createdAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            userDoc = await repo.getUser(fbUser.uid);
          }

          state = userDoc; // ✅ notifier 발생 (UI 자동 갱신)
          await initFcmTokenSync();
          return state;
        }().whenComplete(() {
          _meFuture = null;
        });

    return _meFuture!;
  }

  Future<bool> checkSignIn(BuildContext context) async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;

    if (user != null) {
      await _ensureAndFetchMe(user);
      return true;
    }

    final loginResult = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignInScreen()));

    if (loginResult != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 이용해주세요.')));
      return false;
    }

    final signedInUser = auth.currentUser;
    if (signedInUser == null) return false;

    await _ensureAndFetchMe(signedInUser);
    return true;
  }

  Future<bool> signInWithGoogle() async {
    final auth = ref.read(firebaseAuthProvider);
    final signIn = GoogleSignIn.instance;

    await signIn.initialize(
      serverClientId:
          '307056666844-utebfqasio8tbua4lioi8i0isk4dpji5.apps.googleusercontent.com',
    );

    final GoogleSignInAccount? googleUser = await signIn
        .authenticate();
    if (googleUser == null) return false;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCred = await auth.signInWithCredential(credential);
    final fbUser = userCred.user;
    if (fbUser == null) return false;

    await _ensureAndFetchMe(fbUser);
    return true;
  }

  Future<void> signOut(BuildContext context) async {
    // 1) 로딩(완전 차단)
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final auth = ref.read(firebaseAuthProvider);

      _clearCache(); // ✅ state=null로 notify

      await upsertFcmTokenToUserDoc('');
      await disposeFcmTokenSync();
      await auth.signOut();
      await GoogleSignIn.instance.disconnect();

      if (!context.mounted) return;

      // 2) 로딩 닫기
      Navigator.of(context, rootNavigator: true).pop();

      // 3) 홈까지 돌아간 뒤 로그인 push (뒤로가면 홈)
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SignInScreen()));
    } catch (e) {
      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그아웃 실패: $e')));
    }
  }

  Future<void> updateProfile({
    String? nickName,
    String? photoURL,
  }) async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final updates = <String, dynamic>{};
    final trimmedNickName = nickName?.trim();
    if (trimmedNickName != null && trimmedNickName.isNotEmpty) {
      updates['nickName'] = trimmedNickName;
    }
    if (photoURL != null && photoURL.isNotEmpty) {
      updates['photoURL'] = photoURL;
    }

    if (updates.isEmpty) return;

    await ref
        .read(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .set(updates, SetOptions(merge: true));

    if (state != null) {
      state = state!.copyWith(
        nickName: updates['nickName'] as String? ?? state!.nickName,
        photoURL: updates['photoURL'] as String? ?? state!.photoURL,
      );
    }
  }
}

/// ✅ Provider 변경: state(AppUser?)를 방출하는 NotifierProvider
final authControllerProvider =
    NotifierProvider<AuthController, AppUser?>(AuthController.new);

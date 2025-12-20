// lib/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// FirebaseAuth 인스턴스
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Firebase 인증 상태 스트림 (로그인/로그아웃 변화를 듣는 용도)
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// 실제 로그인/로그아웃 액션 담당 클래스
class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  /// Google + Firebase 로그인
  Future<void> signInWithGoogle() async {
    final auth = _ref.read(firebaseAuthProvider);

    // google_sign_in v7 방식
    final signIn = GoogleSignIn.instance;

    // 필요 시 초기화 (clientId/serverClientId 없으면 기본값으로)
    await signIn.initialize();

    // 사용자가 구글 계정 선택하는 UI
    final GoogleSignInAccount? googleUser = await signIn.authenticate();

    // 사용자가 취소한 경우
    if (googleUser == null) return;

    // 토큰 가져오기
    final googleAuth = await googleUser.authentication;

    // Firebase 크리덴셜 생성 (idToken만으로 충분)
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Firebase 로그인
    await auth.signInWithCredential(credential);
  }

  /// 로그아웃
  Future<void> signOut() async {
    final auth = _ref.read(firebaseAuthProvider);
    await auth.signOut();
    await GoogleSignIn.instance.disconnect();
  }
}

/// 여기서 SignInScreen에서 쓰는 프로바이더
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

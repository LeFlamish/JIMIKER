import '../dataSource/user_source.dart';
import '../models/user.dart';

abstract class UserRepository {
  Stream<AppUser?> watchUser(String uid);
  Future<AppUser?> getUser(String uid);
}

class UserRepositoryImpl implements UserRepository {
  final UserDataSource _ds;
  UserRepositoryImpl(this._ds);

  @override
  Stream<AppUser?> watchUser(String uid) {
    return _ds.watchUserDoc(uid).map((doc) {
      if (!doc.exists) return null;

      // ✅ fromDoc 그대로 사용
      // AppUser.fromDoc는 DocumentSnapshot을 받으니까,
      // 여기서는 doc을 DocumentSnapshot로 볼 수 있게 캐스팅/시그니처 조정 중 하나 필요
      return AppUser.fromDoc(doc);
    });
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final doc = await _ds.getUserDoc(uid); // 1회 조회용 datasource 메서드

    if (!doc.exists) return null;

    return AppUser.fromDoc(doc);
  }
}

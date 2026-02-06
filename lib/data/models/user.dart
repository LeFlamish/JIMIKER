import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { user, manager }

class AppUser {
  final String uid;
  final String email;
  final String nickName;
  final String photoURL;
  final String fcmToken;
  final bool advertisement;
  final UserType userType;

  // ✅ Firestore에도 저장하는 필드면 모델에도 포함
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.nickName,
    required this.photoURL,
    required this.fcmToken,
    required this.advertisement,
    required this.userType,
    this.createdAt,
    this.lastLoginAt,
  });

  factory AppUser.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('User doc ${doc.id} has no data');
    }

    // 방어적으로 읽기(기존 문서에 필드 누락 있어도 크래시 방지)
    final email = (data['email'] is String)
        ? data['email'] as String
        : '';
    final nickName = (data['nickName'] is String)
        ? data['nickName'] as String
        : '';
    final photoURL = (data['photoURL'] is String)
        ? data['photoURL'] as String
        : '';
    final fcmToken = (data['fcmToken'] is String)
        ? data['fcmToken'] as String
        : '';
    final advertisement = (data['advertisement'] is bool)
        ? data['advertisement'] as bool
        : false;

    final userTypeStr = (data['userType'] is String)
        ? data['userType'] as String
        : 'user';

    DateTime? tsToDt(dynamic v) {
      if (v is Timestamp) return v.toDate().toLocal();
      return null;
    }

    return AppUser(
      uid: doc.id,
      email: email,
      nickName: nickName,
      photoURL: photoURL,
      fcmToken: fcmToken,
      advertisement: advertisement,
      userType: UserType.values.firstWhere(
        (t) => t.name == userTypeStr,
        orElse: () => UserType.user,
      ),
      createdAt: tsToDt(data['createdAt']),
      lastLoginAt: tsToDt(data['lastLoginAt']),
    );
  }

  /// ✅ 문서에 저장되는 스키마 그대로
  Map<String, dynamic> toMap() {
    return {
      // 보통 uid는 doc.id가 소스 오브 트루스라서 안 넣어도 되지만,
      // 지금처럼 넣고 싶으면 유지해도 무방합니다.
      'uid': uid,
      'email': email,
      'nickName': nickName,
      'photoURL': photoURL,
      'fcmToken': fcmToken,
      'advertisement': advertisement,
      'userType': userType.name,
      // DateTime -> Timestamp로 저장
      if (createdAt != null)
        'createdAt': Timestamp.fromDate(createdAt!.toUtc()),
      if (lastLoginAt != null)
        'lastLoginAt': Timestamp.fromDate(lastLoginAt!.toUtc()),
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? nickName,
    String? photoURL,
    String? fcmToken,
    bool? advertisement,
    UserType? userType,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nickName: nickName ?? this.nickName,
      photoURL: photoURL ?? this.photoURL,
      fcmToken: fcmToken ?? this.fcmToken,
      advertisement: advertisement ?? this.advertisement,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { user, manager }

class AppUser {
  final String uid;
  final String email;
  final String nickName;
  final String photoURL;
  final bool advertisement;
  final UserType userType;

  AppUser({
    required this.uid,
    required this.email,
    required this.nickName,
    required this.photoURL,
    required this.advertisement,
    required this.userType,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AppUser(
      uid: doc.id,
      email: data['email'],
      nickName: data['nickName'],
      photoURL: data['photoURL'],
      advertisement: data['advertisement'],
      userType: UserType.values.firstWhere(
        (type) => type.name == data['userType'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nickName': nickName,
      'photoURL': photoURL,
      'advertisement': advertisement,
      'userType': userType.name,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? nickName,
    String? photoURL,
    bool? advertisement,
    UserType? userType,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nickName: nickName ?? this.nickName,
      photoURL: photoURL ?? this.photoURL,
      advertisement: advertisement ?? this.advertisement,
      userType: userType ?? this.userType,
    );
  }
}

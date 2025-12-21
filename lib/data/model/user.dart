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
}

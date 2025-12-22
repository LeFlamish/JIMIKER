import 'package:cloud_firestore/cloud_firestore.dart';

abstract class UserDataSource {
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(
    String uid,
  );
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(
    String uid,
  );
}

class UserDataSourceImpl implements UserDataSource {
  final FirebaseFirestore firestore;
  UserDataSourceImpl(this.firestore);

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(
    String uid,
  ) {
    return firestore.collection('users').doc(uid).snapshots();
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(
    String uid,
  ) {
    return firestore.collection('users').doc(uid).get();
  }
}

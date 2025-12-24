import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  const ChatService(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamChatRooms(String uid) {
    return _firestore
        .collection('chat_rooms')
        .where('participantUids', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots();
  }

  Future<void> sendMessage({
    required String roomId,
    required String message,
    required User user,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();

    final payload = {
      'uid': user.uid,
      'displayName': user.displayName ?? user.email ?? '사용자',
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.runTransaction((transaction) async {
      transaction.set(messageRef, payload);
      transaction.set(roomRef, {
        'lastMessage': message,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
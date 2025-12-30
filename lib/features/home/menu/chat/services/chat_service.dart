import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  const ChatService(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamChatRooms(
    String uid,
  ) {
    return _firestore
        .collection('chat_rooms')
        .where('participantUids', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(
    String roomId,
  ) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
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
      'createdAt': Timestamp.now(),
    };
    print(Timestamp.now());
    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final existingParticipants =
          (roomSnapshot.data()?['participantUids'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final participantUids = {
        ...existingParticipants,
        user.uid,
      }.toList();

      if (!roomSnapshot.exists) {
        transaction.set(roomRef, {
          'roomName': '채팅방',
          'createdAt': Timestamp.now(),
        });
      }
      transaction.set(messageRef, payload);
      transaction.set(roomRef, {
        'participantUids': participantUids,
        'lastMessage': message,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> sendSystemMessageToUser({
    required User user,
    required String message,
  }) async {
    final roomId = 'system_${user.uid}';
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final existingParticipants =
          (roomSnapshot.data()?['participantUids'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final participantUids = {
        ...existingParticipants,
        user.uid,
        'system',
      }.toList();

      if (!roomSnapshot.exists) {
        transaction.set(roomRef, {
          'roomName': '지미커(시스템)',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(messageRef, {
        'uid': 'system',
        'displayName': '지미커(시스템)',
        'message': message,
        'createdAt': Timestamp.now(),
      });

      transaction.set(roomRef, {
        'participantUids': participantUids,
        'lastMessage': message,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    });
  }
}

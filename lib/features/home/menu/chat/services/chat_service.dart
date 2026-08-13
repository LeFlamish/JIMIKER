import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  const ChatService(this._firestore);

  final FirebaseFirestore _firestore;

  /// 두 사람 사이의 1:1 채팅방 문서 ID.
  ///
  /// uid를 정렬해서 만들기 때문에 누가 먼저 말을 걸든 항상 같은 방을 가리킨다.
  /// = 양쪽이 동시에 방을 열어도 방이 두 개로 갈라지지 않는다.
  static String directRoomId(String uid, String opponentUid) {
    final uids = [uid, opponentUid]..sort();
    return 'dm_${uids.join('_')}';
  }

  /// 이미 저장된(=메시지가 한 번이라도 오간) 상대와의 방이 있으면 그 id, 없으면 null.
  Future<String?> findExistingRoomId({
    required String uid,
    required String opponentUid,
  }) async {
    if (uid == opponentUid) return null;
    final snapshot = await _firestore
        .collection('chat_rooms')
        .where('participantUids', arrayContains: uid)
        .get();
    for (final doc in snapshot.docs) {
      final participantUids =
          (doc.data()['participantUids'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      if (participantUids.contains(opponentUid)) {
        return doc.id;
      }
    }
    return null;
  }

  /// 상대와 들어갈 방 id를 정한다.
  ///
  /// - 이미 방이 있으면 그 방을 그대로 연다.
  /// - 없으면 새 id만 만들어 돌려준다. **Firestore에는 아직 아무것도 쓰지 않는다.**
  ///   아무 말도 안 하고 나가면 방은 애초에 없던 것과 같아야 하기 때문이다.
  ///   방 문서는 [sendMessage]가 첫 메시지를 넣을 때 함께 만들어진다.
  Future<String> resolveDirectRoomId({
    required String uid,
    required String opponentUid,
  }) async {
    final existingRoomId = await findExistingRoomId(
      uid: uid,
      opponentUid: opponentUid,
    );
    return existingRoomId ?? directRoomId(uid, opponentUid);
  }

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

  /// 메시지를 보낸다. 방 문서가 없으면 이 시점에 만들어진다.
  ///
  /// [participantUids]에 상대 uid를 넣어줘야 방이 새로 생길 때 상대의
  /// 채팅방 목록에도 바로 뜬다. (목록 쿼리가 participantUids로 걸려 있다.)
  Future<void> sendMessage({
    required String roomId,
    required String message,
    required User user,
    List<String> participantUids = const [],
    String? imageUrl,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();
    final now = Timestamp.now();

    // 사진만 보낸 경우 목록에는 '사진'으로 표시한다.
    final preview = message.isNotEmpty
        ? message
        : (imageUrl != null ? '사진' : '');

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final existingParticipants =
          (roomSnapshot.data()?['participantUids'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final mergedParticipants = <String>{
        ...existingParticipants,
        ...participantUids,
        user.uid,
      }..removeWhere((uid) => uid.isEmpty);

      transaction.set(messageRef, {
        'uid': user.uid,
        'displayName': user.displayName ?? user.email ?? '사용자',
        'message': message,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'createdAt': now,
        'read': false,
      });

      transaction.set(roomRef, {
        'participantUids': mergedParticipants.toList(),
        'lastMessage': preview,
        // 목록 우측에 뜨는 "마지막 메시지 시각"의 기준
        'updatedAt': now,
        if (!roomSnapshot.exists) 'createdAt': now,
      }, SetOptions(merge: true));
    });
  }

  /// 채팅 사진을 Storage에 올리고 다운로드 URL을 돌려준다.
  ///
  /// 경로를 방 단위로 나눠서(chat_rooms/{roomId}/...) 방 참여자만 읽도록
  /// Storage 규칙을 걸 수 있게 한다.
  static Future<String> uploadChatImage({
    required FirebaseStorage storage,
    required String roomId,
    required String uid,
    required File file,
  }) async {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final extension = file.path.split('.').last.toLowerCase();
    final reference = storage.ref(
      'chat_rooms/$roomId/${uid}_$timestamp.$extension',
    );

    await reference.putFile(
      file,
      SettableMetadata(customMetadata: {'uid': uid, 'roomId': roomId}),
    );
    return reference.getDownloadURL();
  }

  Future<void> sendSystemMessageToUser({
    required User user,
    required String message,
  }) async {
    final roomId = 'system_${user.uid}';
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();
    final now = Timestamp.now();

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

      transaction.set(messageRef, {
        'uid': 'system',
        'displayName': '지미커(시스템)',
        'message': message,
        'createdAt': now,
        'read': false,
      });

      transaction.set(roomRef, {
        'roomName': '지미커(시스템)',
        'participantUids': participantUids,
        'lastMessage': message,
        'updatedAt': now,
        if (!roomSnapshot.exists) 'createdAt': now,
      }, SetOptions(merge: true));
    });
  }
}

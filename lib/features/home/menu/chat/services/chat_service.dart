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

  /// dm 방 id에 박혀 있는 두 참여자 uid. 못 읽는 형태면 빈 목록.
  ///
  /// 방 id는 [directRoomId]가 'dm_{uid}_{uid}' 꼴로 만들고 Firebase uid에는
  /// 밑줄이 없어서 되돌려 읽을 수 있다. 부르는 쪽이 상대 uid를 빠뜨려도
  /// 여기서 복원해, 참여자가 한 명뿐인 방(상대 목록에 안 뜨는 방)이
  /// 만들어지는 일을 막는다.
  static List<String> participantsFromRoomId(String roomId) {
    if (!roomId.startsWith('dm_')) return const [];
    final uids = roomId.substring(3).split('_');
    if (uids.length != 2) return const [];
    if (uids.any((uid) => uid.isEmpty)) return const [];
    return uids;
  }

  /// dm 방 참여자 목록에 나 말고 아무도 남지 않았는가.
  ///
  /// 상대가 방을 나가면 참여자 목록에서 빠지므로 이 상태가 된다.
  /// 화면은 이때 상대를 「알 수 없음」으로 보여준다. 방 id에는 상대 uid가
  /// 남아 있지만, 나간 사람을 다시 알아내는 데 쓰지 않는다.
  static bool opponentMissing({
    required String roomId,
    required Iterable<String> participants,
    required String? myUid,
  }) {
    if (!roomId.startsWith('dm_')) return false;
    return !participants.any((uid) => uid != myUid);
  }

  /// 메시지를 보낼 때 방 참여자 목록을 다시 계산한다.
  ///
  /// - 방을 나간 사람([left])은 남이 메시지를 보내도 되살아나지 않는다.
  /// - 보낸 사람 본인은 항상 참여자다. 나갔던 방에 내가 다시 말을 걸면
  ///   그 순간 복귀한다.
  /// - 방 id에 든 두 사람을 합쳐, 참여자가 한 명뿐인 옛 방도 복구한다.
  static List<String> mergeParticipants({
    required String roomId,
    required Iterable<String> existing,
    required Iterable<String> requested,
    required Iterable<String> left,
    required String senderUid,
  }) {
    final leftSet = left.toSet();
    final merged =
        <String>{
            ...existing,
            ...requested,
            ...participantsFromRoomId(roomId),
          }
          ..removeWhere(
            (uid) => uid.isEmpty || leftSet.contains(uid),
          )
          ..add(senderUid);
    return merged.toList();
  }

  /// 방을 나간다: 참여자에서 나만 빠지고, 나간 사람 목록(leftUids)에 남는다.
  ///
  /// 메시지는 지우지 않으므로 상대에게는 대화가 그대로 남는다. 다만 내가
  /// 참여자에서 빠져 상대 화면에는 「알 수 없음」으로 표시되고, 상대가
  /// 보내는 메시지도 leftUids 덕분에 나를 되살리지 못한다.
  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  }) {
    return _firestore.collection('chat_rooms').doc(roomId).update({
      'participantUids': FieldValue.arrayRemove([uid]),
      'leftUids': FieldValue.arrayUnion([uid]),
      // 내 안 읽음 수는 더 이상 의미가 없다.
      'unreadCounts.$uid': FieldValue.delete(),
    });
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

  /// 한 번에 보여줄 메시지 수.
  static const int messagePageSize = 200;

  /// 최근 메시지부터 [messagePageSize]개.
  ///
  /// 오름차순으로 자르면 "가장 오래된 200개"가 잡혀서, 대화가 200개를 넘는
  /// 순간부터 새 메시지가 영영 안 보인다. 최신순으로 자른 뒤 화면에서
  /// 뒤집어(reverse) 보여준다.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(
    String roomId,
  ) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(messagePageSize)
        .snapshots();
  }

  /// 최신이 앞에 오도록 정렬한다.
  ///
  /// 방금 보낸 메시지는 서버 시각(serverTimestamp)이 아직 안 찍혀
  /// createdAt이 비어 있다. Firestore는 그런 문서를 정렬에서 가장 앞으로
  /// 보내는데, 그대로 두면 내가 쓴 말이 대화 맨 끝에 잠깐 나타난다.
  /// 아직 안 찍힌 것은 "가장 최신"으로 본다.
  static List<T> sortNewestFirst<T>(
    Iterable<T> items,
    Timestamp? Function(T item) createdAt,
  ) {
    // 어떤 실제 시각보다도 뒤. Timestamp가 다룰 수 있는 범위를 넘는다.
    const pending = 1 << 62;

    int sentAt(T item) =>
        createdAt(item)?.millisecondsSinceEpoch ?? pending;

    return [...items]..sort((a, b) => sentAt(b).compareTo(sentAt(a)));
  }

  /// 상대가 보낸 안 읽은 메시지를 읽음으로 바꾼다.
  ///
  /// 규칙상 메시지에서 고칠 수 있는 건 read 하나뿐이라 그것만 건드린다.
  /// 방 문서의 안 읽은 수도 0으로 되돌린다. (세는 건 Functions가 한다)
  Future<void> markRoomAsRead({
    required String roomId,
    required String uid,
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>>
    messages,
  }) async {
    final unread = messages.where((doc) {
      final data = doc.data();
      return data['uid'] != uid && data['read'] != true;
    }).toList();

    if (unread.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    batch.set(_firestore.collection('chat_rooms').doc(roomId), {
      'unreadCounts': {uid: 0},
    }, SetOptions(merge: true));

    await batch.commit();
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
      final roomData = roomSnapshot.data();
      final existingParticipants =
          (roomData?['participantUids'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final leftUids =
          (roomData?['leftUids'] as List<dynamic>?)?.cast<String>() ??
          [];

      final mergedParticipants = mergeParticipants(
        roomId: roomId,
        existing: existingParticipants,
        requested: participantUids,
        left: leftUids,
        senderUid: user.uid,
      );
      // 내가 보낸 순간 나는 "나간 사람"이 아니다.
      final remainingLeft = leftUids
          .where((uid) => uid != user.uid)
          .toList();

      transaction.set(messageRef, {
        'uid': user.uid,
        'displayName': user.displayName ?? user.email ?? '사용자',
        'message': message,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'createdAt': now,
        'read': false,
      });

      transaction.set(roomRef, {
        'participantUids': mergedParticipants,
        'leftUids': remainingLeft,
        'lastMessage': preview,
        // 목록 우측에 뜨는 "마지막 메시지 시각"의 기준
        'updatedAt': now,
        if (!roomSnapshot.exists) 'createdAt': now,
      }, SetOptions(merge: true));
    });
  }

  /// 방 문서 스트림. 참여자 목록(상대가 나갔는지)을 지켜볼 때 쓴다.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRoom(
    String roomId,
  ) {
    return _firestore.collection('chat_rooms').doc(roomId).snapshots();
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
        // 알림 방은 나가도 새 알림이 오면 다시 열린다.
        // (예약 승인 같은 중요한 안내를 놓치면 안 되기 때문)
        'leftUids': FieldValue.arrayRemove([user.uid]),
        'lastMessage': message,
        'updatedAt': now,
        if (!roomSnapshot.exists) 'createdAt': now,
      }, SetOptions(merge: true));
    });
  }
}

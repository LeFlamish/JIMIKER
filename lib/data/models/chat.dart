import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _toLocalDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate().toLocal();
  // serverTimestamp 직후 아직 null일 수 있음
  return DateTime.fromMillisecondsSinceEpoch(0).toLocal();
}

class ChatRoom {
  final String id;
  final List<String> participantUids; // Firestore: participantUids
  final String roomName; // Firestore: roomName
  final String? lastMessage; // Firestore: lastMessage
  final DateTime createdAt; // Firestore: createdAt
  final DateTime updatedAt; // Firestore: updatedAt

  const ChatRoom({
    required this.id,
    required this.participantUids,
    required this.roomName,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatRoom.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatRoom(
      id: doc.id,
      participantUids:
          (data['participantUids'] as List<dynamic>? ?? [])
              .cast<String>(),
      roomName: (data['roomName'] as String?) ?? '채팅방',
      lastMessage: data['lastMessage'] as String?,
      createdAt: _toLocalDateTime(data['createdAt']),
      updatedAt: _toLocalDateTime(data['updatedAt']),
    );
  }

  /// Firestore 저장용 (ChatService 구조와 동일)
  Map<String, dynamic> toMap({bool useServerTimestamps = false}) {
    return {
      'participantUids': participantUids,
      'roomName': roomName,
      'lastMessage': lastMessage,
      'createdAt': useServerTimestamps
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt.toUtc()),
      'updatedAt': useServerTimestamps
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt.toUtc()),
    };
  }

  ChatRoom copyWith({
    List<String>? participantUids,
    String? roomName,
    String? lastMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatRoom(
      id: id,
      participantUids: participantUids ?? this.participantUids,
      roomName: roomName ?? this.roomName,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChatMessage {
  final String id;
  final String uid; // Firestore: uid
  final String displayName; // Firestore: displayName
  final String message; // Firestore: message
  final String? imageUrl; // (옵션) Firestore: imageUrl
  final DateTime createdAt; // Firestore: createdAt

  const ChatMessage({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.message,
    required this.imageUrl,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatMessage(
      id: doc.id,
      uid: (data['uid'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '사용자',
      message: (data['message'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: _toLocalDateTime(data['createdAt']),
    );
  }

  /// Firestore 저장용 (ChatService payload와 동일)
  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'uid': uid,
      'displayName': displayName,
      'message': message,
      'imageUrl': imageUrl,
      'createdAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt.toUtc()),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final List<String> participantUids;
  final String? lastMessage;
  final DateTime createdAt;
  final String roomName;
  final DateTime updatedAt;
  ChatRoom({
    required this.id,
    required this.participantUids,
    required this.lastMessage,
    required this.createdAt,
    required this.roomName,
    required this.updatedAt,
  });

  factory ChatRoom.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      participantUids: List<String>.from(data['participants']),
      lastMessage: data['lastMessage'],
      createdAt: (data['createdAt'] as Timestamp).toDate().toLocal(),
      roomName: data['roomName'],
      updatedAt: (data['updatedAt'] as Timestamp).toDate().toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participantUids,
      'lastMessage': lastMessage,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'roomName': roomName,
      'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
    };
  }

  ChatRoom copyWith({
    List<String>? participants,
    String? lastMessage,
    String? roomName,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return ChatRoom(
      id: id,
      participantUids: participants ?? this.participantUids,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      roomName: roomName ?? this.roomName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String? content;
  final String? imageUrl;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.imageUrl,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'],
      content: data['content'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate().toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    };
  }
}

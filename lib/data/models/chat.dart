import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final List<String> participants;
  final String? lastMessage;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.lastMessage,
  });

  factory ChatRoom.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      participants: List<String>.from(data['participants']),
      lastMessage: data['lastMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'participants': participants, 'lastMessage': lastMessage};
  }

  ChatRoom copyWith({
    List<String>? participants,
    String? lastMessage,
  }) {
    return ChatRoom(
      id: id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    };
  }
}

class ChatRoom {
  final String id;
  final List<String> participants;
  final String? lastMessage;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.lastMessage,
  });
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
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jimiker/features/home/menu/chat/screens/chat_room_screen.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';
import 'package:jimiker/features/home/menu/chat/widgets/chat_room_list_tile.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인 후 이용해주세요.')),
      );
    }

    final chatService = ChatService(FirebaseFirestore.instance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatService.streamChatRooms(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data?.docs ?? [];
          if (rooms.isEmpty) {
            return const Center(
              child: Text('열려있는 채팅방이 없습니다.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = rooms[index];
              final data = doc.data();
              final roomName = data['roomName']?.toString() ?? '채팅방';
              final lastMessage =
                  data['lastMessage']?.toString() ?? '메시지가 없습니다.';
              final updatedAt = data['updatedAt'] as Timestamp?;

              return ChatRoomListTile(
                roomName: roomName,
                lastMessage: lastMessage,
                updatedAt: updatedAt,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        roomId: doc.id,
                        roomName: roomName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
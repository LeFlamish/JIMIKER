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
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: chatService.streamChatRooms(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              // 콘솔에서 에러 메시지 확인
              debugPrint('chat rooms error: ${snapshot.error}');
              return Center(child: Text('에러: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rooms =
                List<
                    QueryDocumentSnapshot<Map<String, dynamic>>
                  >.from(snapshot.data?.docs ?? [])
                  ..sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();
                    final aUpdatedAt =
                        aData['updatedAt'] as Timestamp?;
                    final bUpdatedAt =
                        bData['updatedAt'] as Timestamp?;
                    final aCreatedAt =
                        aData['createdAt'] as Timestamp?;
                    final bCreatedAt =
                        bData['createdAt'] as Timestamp?;
                    final aTime =
                        (aUpdatedAt ?? aCreatedAt)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final bTime =
                        (bUpdatedAt ?? bCreatedAt)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return bTime.compareTo(aTime);
                  });

            if (rooms.isEmpty) {
              return const Center(child: Text('열려있는 채팅방이 없습니다.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = rooms[index];
                final data = doc.data();
                final lastMessage =
                    data['lastMessage']?.toString() ?? '메시지가 없습니다.';
                final updatedAt = data['updatedAt'] as Timestamp?;

                final participantUids =
                    (data['participantUids'] as List<dynamic>?)
                        ?.cast<String>() ??
                    [];
                final opponentUid = participantUids.firstWhere(
                  (uid) => uid != user.uid,
                  orElse: () => '',
                );

                return StreamBuilder<
                  DocumentSnapshot<Map<String, dynamic>>
                >(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(opponentUid)
                      .snapshots(),
                  builder: (context, userSnapshot) {
                    final userData = userSnapshot.data?.data();
                    final opponentName = userData?['nickName']
                        ?.toString()
                        .trim();
                    final opponentPhotoUrl = userData?['photoURL']
                        ?.toString();
                    final displayName =
                        (opponentName == null || opponentName.isEmpty)
                        ? "지미커"
                        : opponentName;

                    return ChatRoomListTile(
                      roomName: displayName,
                      photoUrl: opponentPhotoUrl,
                      lastMessage: lastMessage,
                      updatedAt: updatedAt,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              roomId: doc.id,
                              roomName: displayName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

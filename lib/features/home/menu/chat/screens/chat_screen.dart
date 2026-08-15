import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jimiker/features/home/menu/chat/screens/chat_room_screen.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';
import 'package:jimiker/features/home/menu/chat/widgets/chat_room_list_item.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('채팅'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: chatService.streamChatRooms(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              // 콘솔에서 에러 메시지 확인
              debugPrint('chat rooms error: ${snapshot.error}');
              return Center(
                child: Text(
                  '채팅 목록을 불러오지 못했어요.\n잠시 후 다시 열어주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rooms =
                (snapshot.data?.docs ?? [])
                    // 메시지가 한 번도 오가지 않은 방은 "없는 방"과 같으므로 숨긴다.
                    .where((doc) => _hasMessage(doc.data()))
                    .toList()
                  ..sort((a, b) {
                    final aTime = _sortTime(a.data());
                    final bTime = _sortTime(b.data());
                    return bTime.compareTo(aTime);
                  });

            if (rooms.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '아직 대화가 없어요.\n예약하거나 예약을 받으면 1:1 대화가 열려요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = rooms[index];
                final data = doc.data();

                final participantUids =
                    (data['participantUids'] as List<dynamic>?)
                        ?.cast<String>() ??
                    [];
                final opponentUid = participantUids.firstWhere(
                  (uid) => uid != user.uid,
                  orElse: () => '',
                );
                final fallbackName =
                    data['roomName']?.toString().trim().isNotEmpty ==
                        true
                    ? data['roomName'].toString().trim()
                    : '지미커';

                return ChatRoomListItem(
                  key: ValueKey(doc.id),
                  opponentUid: opponentUid,
                  fallbackName: fallbackName,
                  lastMessage:
                      data['lastMessage']?.toString() ?? '메시지가 없습니다.',
                  // 목록 우측 시간 = 마지막으로 메시지가 오간 시각
                  updatedAt: data['updatedAt'] as Timestamp?,
                  unreadCount: _unreadCount(data, user.uid),
                  onTap: (opponentName) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomScreen(
                          roomId: doc.id,
                          roomName: opponentName,
                          opponentUid: opponentUid.isEmpty
                              ? null
                              : opponentUid,
                        ),
                      ),
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

  bool _hasMessage(Map<String, dynamic> data) {
    final lastMessage = data['lastMessage'];
    return lastMessage is String && lastMessage.trim().isNotEmpty;
  }

  /// 내가 안 읽은 메시지 수. Functions가 방 문서에 세어 둔 값을 읽는다.
  ///
  /// 함수가 아직 배포되지 않았거나 예전에 만들어진 방에는 이 값이 없다.
  /// 그때는 0으로 보고 뱃지를 띄우지 않는다. (틀린 숫자를 보여주느니 낫다)
  int _unreadCount(Map<String, dynamic> data, String uid) {
    final counts = data['unreadCounts'];
    if (counts is! Map) return 0;
    return (counts[uid] as num?)?.toInt() ?? 0;
  }

  int _sortTime(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'] as Timestamp?;
    final createdAt = data['createdAt'] as Timestamp?;
    return (updatedAt ?? createdAt)?.millisecondsSinceEpoch ?? 0;
  }
}

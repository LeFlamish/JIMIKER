import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:jimiker/features/home/menu/chat/widgets/chat_room_list_tile.dart';

/// 채팅방 목록의 한 줄.
///
/// 상대 프로필 구독을 위젯이 살아있는 동안 한 번만 만든다.
/// (ListView의 itemBuilder 안에서 StreamBuilder를 바로 만들면 rebuild마다
///  스냅샷 리스너가 새로 붙어서 읽기가 낭비된다.)
class ChatRoomListItem extends StatefulWidget {
  const ChatRoomListItem({
    super.key,
    required this.opponentUid,
    required this.fallbackName,
    required this.lastMessage,
    required this.updatedAt,
    required this.onTap,
    this.onLongPress,
    this.unreadCount = 0,
  });

  final String opponentUid;

  /// 상대 정보를 못 읽었을 때 쓸 이름 (시스템 방 이름 등)
  final String fallbackName;
  final String lastMessage;
  final Timestamp? updatedAt;

  /// 이 방에서 내가 아직 안 읽은 메시지 수
  final int unreadCount;

  /// 화면에 보이는 상대 이름을 그대로 채팅방 제목으로 넘겨준다.
  final void Function(String opponentName) onTap;

  /// 길게 눌렀을 때. 확인 문구에 쓰도록 화면에 보이는 이름을 넘겨준다.
  final void Function(String opponentName)? onLongPress;

  @override
  State<ChatRoomListItem> createState() => _ChatRoomListItemState();
}

class _ChatRoomListItemState extends State<ChatRoomListItem> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _opponentStream;

  @override
  void initState() {
    super.initState();
    _bindOpponentStream();
  }

  @override
  void didUpdateWidget(covariant ChatRoomListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opponentUid != widget.opponentUid) {
      _bindOpponentStream();
    }
  }

  void _bindOpponentStream() {
    final uid = widget.opponentUid;
    _opponentStream = uid.isEmpty
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _opponentStream;
    if (stream == null) {
      return _buildTile(name: widget.fallbackName, photoUrl: null);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final nickName = data?['nickName']?.toString().trim();
        return _buildTile(
          name: (nickName == null || nickName.isEmpty)
              ? widget.fallbackName
              : nickName,
          photoUrl: data?['photoURL']?.toString(),
        );
      },
    );
  }

  Widget _buildTile({required String name, required String? photoUrl}) {
    final onLongPress = widget.onLongPress;
    return ChatRoomListTile(
      roomName: name,
      photoUrl: photoUrl,
      lastMessage: widget.lastMessage,
      updatedAt: widget.updatedAt,
      unreadCount: widget.unreadCount,
      onTap: () => widget.onTap(name),
      onLongPress: onLongPress == null
          ? null
          : () => onLongPress(name),
    );
  }
}

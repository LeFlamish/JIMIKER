import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:jimiker/core/utils/kst_time.dart';
import 'package:jimiker/core/widgets/cached_image.dart';

class ChatRoomListTile extends StatelessWidget {
  final String roomName;
  final String? photoUrl;
  final String lastMessage;

  /// 마지막으로 메시지가 오간 시각 (한국 기준으로 표시된다)
  final Timestamp? updatedAt;

  /// 아직 안 읽은 메시지 수. 0이면 뱃지를 띄우지 않는다.
  final int unreadCount;
  final VoidCallback onTap;

  /// 길게 눌렀을 때 (채팅방 나가기 메뉴)
  final VoidCallback? onLongPress;

  const ChatRoomListTile({
    super.key,
    required this.roomName,
    required this.photoUrl,
    required this.lastMessage,
    required this.updatedAt,
    required this.onTap,
    this.onLongPress,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return ListTile(
      title: Text(
        roomName,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      leading: CachedAvatar(photoUrl: photoUrl),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hasUnread ? Colors.black87 : Colors.grey.shade600,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatKstChatListTime(updatedAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: hasUnread
                  ? const Color(0xFF6B7AF5)
                  : Colors.grey.shade600,
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 2,
              ),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7AF5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                // 세 자리가 넘어가면 자리를 너무 먹는다.
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

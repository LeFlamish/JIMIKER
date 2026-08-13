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
  final VoidCallback onTap;

  const ChatRoomListTile({
    super.key,
    required this.roomName,
    required this.photoUrl,
    required this.lastMessage,
    required this.updatedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(roomName),
      leading: CachedAvatar(photoUrl: photoUrl),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatKstChatListTime(updatedAt),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
      ),
      onTap: onTap,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatRoomListTile extends StatelessWidget {
  final String roomName;
  final String lastMessage;
  final Timestamp? updatedAt;
  final VoidCallback onTap;

  const ChatRoomListTile({
    super.key,
    required this.roomName,
    required this.lastMessage,
    required this.updatedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(roomName),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTime(context, updatedAt),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
      ),
      onTap: onTap,
    );
  }

  String _formatTime(BuildContext context, Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate().toLocal();
    final time = TimeOfDay.fromDateTime(dateTime);
    return time.format(context);
  }
}

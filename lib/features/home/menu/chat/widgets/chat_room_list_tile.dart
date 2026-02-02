import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatRoomListTile extends StatelessWidget {
  final String roomName;
  final String? photoUrl;
  final String lastMessage;
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
      leading: _ProfileAvatar(photoUrl: photoUrl),
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

class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;

  const _ProfileAvatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (photoUrl == null || photoUrl!.isEmpty) {
      return CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return CircleAvatar(backgroundImage: NetworkImage(photoUrl!));
  }
}

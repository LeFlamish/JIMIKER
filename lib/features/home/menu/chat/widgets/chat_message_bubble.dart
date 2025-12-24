import 'package:flutter/material.dart';

class ChatMessageBubble extends StatelessWidget {
  final bool isMine;
  final String displayName;
  final String message;
  final String timeLabel;

  const ChatMessageBubble({
    super.key,
    required this.isMine,
    required this.displayName,
    required this.message,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isMine
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : Colors.grey.shade200;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
          ),
          if (timeLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
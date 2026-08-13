import 'package:flutter/material.dart';
import 'package:jimiker/core/widgets/cached_image.dart';

class ChatMessageBubble extends StatelessWidget {
  final bool isMine;
  final String displayName;
  final String message;

  /// 사진 메시지면 채워진다. 글과 사진이 같이 올 수도 있다.
  final String? imageUrl;
  final String timeLabel;

  const ChatMessageBubble({
    super.key,
    required this.isMine,
    required this.displayName,
    required this.message,
    required this.timeLabel,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isMine
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : Colors.grey.shade200;
    final photoUrl = imageUrl;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (photoUrl != null && photoUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _openFullScreen(context, photoUrl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: CachedImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (message.isNotEmpty) const SizedBox(height: 8),
          ],
          if (message.isNotEmpty)
            Text(message, style: theme.textTheme.bodyMedium),
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

  /// 사진을 눌렀을 때 확대해서 보기
  void _openFullScreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: CachedImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

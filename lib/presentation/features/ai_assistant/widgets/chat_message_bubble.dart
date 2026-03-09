import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// A single chat message bubble.
///
/// User messages are right-aligned with primary background.
/// Assistant messages are left-aligned with surface background and markdown rendering.
class ChatMessageBubble extends StatelessWidget {
  final String role; // 'user' or 'assistant'
  final String content;
  final bool isStreaming;

  const ChatMessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  bool get _isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = _isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                content,
                style: TextStyle(color: colorScheme.onPrimary),
              )
            else
              MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                  p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                ),
                onTapLink: (text, href, title) {
                  // Only allow https:// links — prevent tel:, sms:, etc.
                  if (href != null && href.startsWith('https://')) {
                    launchUrl(Uri.parse(href),
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
            if (isStreaming) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

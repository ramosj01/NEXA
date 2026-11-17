import 'package:flutter/material.dart';

import '../theme/nexa_colors.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.mine,
    this.read = false,
    this.onLongPress,
  });

  final String text;
  final String time;
  final bool mine;
  final bool read;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final fg = mine ? c.onBubbleSent : c.onBubbleReceived;
    const r = Radius.circular(20);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
            decoration: BoxDecoration(
              color: mine ? c.bubbleSent : c.bubbleReceived,
              borderRadius: BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: mine ? r : const Radius.circular(6),
                bottomRight: mine ? const Radius.circular(6) : r,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(text, style: TextStyle(color: fg, fontSize: 16, height: 1.3)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12)),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(read ? Icons.done_all : Icons.done, size: 14, color: fg.withValues(alpha: 0.8)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

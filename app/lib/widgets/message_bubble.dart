import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/nexa_colors.dart';

/// Chat bubble for text, image and voice messages.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.onLongPress});

  final DemoMessage message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final m = message;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = m.mine ? c.onBubbleSent : c.onBubbleReceived;
    const r = Radius.circular(18);
    final shape = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: m.mine ? r : const Radius.circular(4),
      bottomRight: m.mine ? const Radius.circular(4) : r,
    );
    final decoration = BoxDecoration(
      borderRadius: shape,
      color: m.mine ? null : c.bubbleReceived,
      gradient: m.mine
          ? LinearGradient(colors: [isDark ? const Color(0xFF6366F1) : NexaBrand.indigo, NexaBrand.violet])
          : null,
    );

    final meta = _Meta(time: m.time, mine: m.mine, read: m.read, color: fg.withValues(alpha: 0.75));

    final Widget content = switch (m.kind) {
      MessageKind.image => ClipRRect(
          borderRadius: shape,
          child: SizedBox(
            width: 230,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _BeachPainter()),
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _Meta(time: m.time, mine: true, read: m.read, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      MessageKind.voice => Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
          decoration: decoration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: m.mine ? NexaBrand.indigo : c.bubbleReceived),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Waveform(color: fg),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(m.duration ?? '', style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 11)),
                      const SizedBox(width: 70),
                      meta,
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      MessageKind.text => Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 7),
          decoration: decoration,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(m.body, style: TextStyle(color: fg, fontSize: 15, height: 1.3)),
              Padding(padding: const EdgeInsets.only(top: 4), child: meta),
            ],
          ),
        ),
    };

    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                content,
                if (m.hearts > 0)
                  Transform.translate(
                    offset: const Offset(-6, -6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_rounded, size: 14, color: NexaStatus.error),
                          const SizedBox(width: 3),
                          Text('${m.hearts}', style: TextStyle(fontSize: 12, color: c.textPrimary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.time, required this.mine, required this.read, required this.color});
  final String time;
  final bool mine;
  final bool read;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: TextStyle(color: color, fontSize: 11)),
        if (mine) ...[
          const SizedBox(width: 3),
          Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: color),
        ],
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.color});
  final Color color;

  static const _heights = [6, 10, 16, 9, 20, 14, 8, 18, 22, 12, 7, 15, 19, 10, 6, 13, 17, 9, 5, 11, 15, 8];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in _heights)
            Container(
              width: 3,
              height: h.toDouble(),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }
}

/// Illustrated stand-in for a shared photo until media upload exists.
class _BeachPainter extends CustomPainter {
  const _BeachPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final sky = Rect.fromLTWH(0, 0, s.width, s.height * 0.55);
    canvas.drawRect(
      sky,
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7DD3FC), Color(0xFFE0F2FE)],
      ).createShader(sky),
    );
    canvas.drawCircle(Offset(s.width * 0.22, s.height * 0.22), 14, Paint()..color = const Color(0xFFFDE68A));
    final sea = Rect.fromLTWH(0, s.height * 0.5, s.width, s.height * 0.3);
    canvas.drawRect(
      sea,
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0EA5E9), Color(0xFF2DD4BF)],
      ).createShader(sea),
    );
    final sand = Path()
      ..moveTo(0, s.height * 0.78)
      ..quadraticBezierTo(s.width * 0.5, s.height * 0.68, s.width, s.height * 0.8)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(sand, Paint()..color = const Color(0xFFFDE7C3));
    // Palm tree
    final trunk = Paint()
      ..color = const Color(0xFF92400E)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final base = Offset(s.width * 0.8, s.height * 0.85);
    final top = Offset(s.width * 0.72, s.height * 0.25);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(s.width * 0.82, s.height * 0.5, top.dx, top.dy),
      trunk,
    );
    final leaf = Paint()
      ..color = const Color(0xFF15803D)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final d in const [Offset(-34, 10), Offset(-26, -12), Offset(30, -10), Offset(36, 12), Offset(4, -22)]) {
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(top.dx + d.dx * 0.5, top.dy + d.dy - 10, top.dx + d.dx, top.dy + d.dy + 8),
        leaf,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

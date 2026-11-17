import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../assistant/assistant_api.dart';
import '../assistant/background_service.dart';
import '../assistant/jarvis_controller.dart';
import '../theme/nexa_colors.dart';

class JarvisScreen extends StatefulWidget {
  const JarvisScreen({super.key, JarvisController? controller}) : _controller = controller;
  final JarvisController? _controller;

  @override
  State<JarvisScreen> createState() => _JarvisScreenState();
}

class _JarvisScreenState extends State<JarvisScreen> with SingleTickerProviderStateMixin {
  late final JarvisController j = widget._controller ?? jarvis;
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    j.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    j.removeListener(_onChange);
    _spin.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _status => switch (j.state) {
        JarvisState.idle => 'Tap to talk',
        JarvisState.wakeListening => 'Say "Jarvis" or tap to talk',
        JarvisState.listening => j.partial.isEmpty ? 'Listening…' : j.partial,
        JarvisState.thinking => 'Working on it…',
        JarvisState.speaking => 'Speaking · tap to stop',
      };

  void _onOrbTap() {
    switch (j.state) {
      case JarvisState.speaking:
        j.stopSpeaking();
      case JarvisState.thinking:
        break;
      default:
        j.listen();
    }
  }

  void _submitTyped() {
    final t = _input.text.trim();
    if (t.isEmpty || j.state == JarvisState.thinking) return;
    _input.clear();
    j.send(t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jarvis'),
        actions: [
          if (j.transcript.isNotEmpty)
            IconButton(
              tooltip: 'Clear conversation',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: j.clearTranscript,
            ),
          IconButton(
            tooltip: 'Jarvis settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => _JarvisSettings(controller: j),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (j.digest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Chip(
                avatar: const Icon(Icons.inbox_rounded, size: 18),
                label: Text(j.digest!),
              ),
            ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: _status,
            child: GestureDetector(
              onTap: _onOrbTap,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (_, __) => CustomPaint(
                  size: const Size.square(200),
                  painter: _OrbPainter(
                    t: _spin.value,
                    state: j.state,
                    level: j.soundLevel,
                    dark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _status,
                key: ValueKey(_status),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: c.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (j.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(j.error!, textAlign: TextAlign.center, style: const TextStyle(color: NexaStatus.error)),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: j.transcript.isEmpty
                ? _Suggestions(onPick: j.send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: j.transcript.length,
                    itemBuilder: (_, i) => _EntryTile(entry: j.transcript[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitTyped(),
                      decoration: const InputDecoration(hintText: 'Or type to Jarvis…', isDense: true),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _submitTyped,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});
  final void Function(String) onPick;

  static const _items = [
    "What's waiting on me?",
    'What are my tasks today?',
    'Summarise the Project chat',
    'Remind me to send the deck Friday',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [for (final s in _items) ActionChip(label: Text(s), onPressed: () => onPick(s))],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final JarvisEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final mine = entry.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: mine ? NexaBrand.ctaGradient : null,
                color: mine ? null : c.bubbleReceived,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(entry.text, style: TextStyle(color: mine ? Colors.white : c.onBubbleReceived)),
            ),
            for (final a in entry.actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      a.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 14,
                      color: a.ok ? NexaStatus.success : NexaStatus.error,
                    ),
                    const SizedBox(width: 4),
                    Flexible(child: Text(a.summary, style: TextStyle(fontSize: 12, color: c.textSecondary))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JarvisSettings extends StatelessWidget {
  const _JarvisSettings({required this.controller});
  final JarvisController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.hearing_rounded),
              title: const Text('"Jarvis" wake word'),
              subtitle: Text(AssistantConfig.hasWakeWord
                  ? 'Listens on-device for "Jarvis". Audio never leaves the phone until you speak a request.'
                  : 'Build with --dart-define=PICOVOICE_ACCESS_KEY=… to enable.'),
              value: controller.wakeWordEnabled,
              onChanged: AssistantConfig.hasWakeWord ? controller.setWakeWord : null,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.nightlight_round),
              title: const Text('Run in background'),
              subtitle: Text(JarvisBackground.supported
                  ? 'Keeps Jarvis available from a notification, even with the app closed.'
                  : 'Background mode is available on Android only.'),
              value: controller.backgroundEnabled,
              onChanged: JarvisBackground.supported ? controller.setBackground : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// An arc-reactor style orb: rotating segmented rings around a glowing core
/// whose colour and pulse follow the assistant's state.
class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t, required this.state, required this.level, required this.dark});

  final double t;
  final JarvisState state;
  final double level;
  final bool dark;

  Color get _color => switch (state) {
        JarvisState.idle => NexaBrand.indigo,
        JarvisState.wakeListening => NexaBrand.indigo,
        JarvisState.listening => NexaBrand.sky,
        JarvisState.thinking => NexaBrand.violet,
        JarvisState.speaking => NexaBrand.teal,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final color = _color;
    final angle = t * 2 * math.pi;

    // Pulse: driven by mic level while listening, a slow breath otherwise.
    final lvl = state == JarvisState.listening ? (level.clamp(-2, 10) + 2) / 12 : 0.0;
    final breath = 0.5 + 0.5 * math.sin(angle * (state == JarvisState.speaking ? 6 : 2));
    final pulse = state == JarvisState.listening ? lvl : breath * (state == JarvisState.idle ? 0.15 : 0.4);

    // Glow.
    canvas.drawCircle(
      center,
      r * (0.55 + 0.1 * pulse),
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: r * 0.75)),
    );

    // Core.
    canvas.drawCircle(
      center,
      r * (0.24 + 0.05 * pulse),
      Paint()
        ..shader = RadialGradient(colors: [Colors.white, color, color.withValues(alpha: 0.6)], stops: const [0, 0.55, 1])
            .createShader(Rect.fromCircle(center: center, radius: r * 0.3)),
    );

    // Rings: radius fraction, segment count, stroke, direction, speed.
    final rings = [(0.42, 3, 4.0, 1.0, 1.0), (0.62, 6, 2.5, -1.0, 0.6), (0.84, 12, 2.0, 1.0, 0.35)];
    final fast = state == JarvisState.thinking ? 3.0 : 1.0;
    for (final (frac, segments, stroke, dir, speed) in rings) {
      final rr = r * frac;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: dark ? 0.85 : 0.75);
      final sweep = 2 * math.pi / segments;
      for (var i = 0; i < segments; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: rr),
          angle * dir * speed * fast + i * sweep,
          sweep * 0.6,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t || old.state != state || old.level != level || old.dark != dark;
}

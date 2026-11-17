import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/nexa_colors.dart';
import '../widgets/avatar.dart';
import '../widgets/gradient_button.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat});
  final DemoChat chat;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final _messages = demoMessagesFor(widget.chat);
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now().format(context);
    setState(() => _messages.add(DemoMessage(text, now, mine: true)));
    _input.clear();
  }

  /// Chat-to-Task: the user reviews the suggested task before it is created.
  Future<void> _createTask(DemoMessage m) async {
    if (m.kind != MessageKind.text) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _TaskSheet(initialTitle: m.body),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final chat = widget.chat;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            NexaAvatar(name: chat.name, size: 40, online: chat.online, isGroup: chat.isGroup),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      if (chat.online) ...[
                        const Icon(Icons.circle, size: 8, color: NexaStatus.success),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        chat.isGroup ? '${chat.members} members' : (chat.online ? 'Online' : 'Last seen recently'),
                        style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.call_rounded, color: primary), tooltip: 'Call'),
          IconButton(onPressed: () {}, icon: Icon(Icons.videocam_rounded, color: primary), tooltip: 'Video call'),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                for (final m in _messages) MessageBubble(message: m, onLongPress: () => _createTask(m)),
                const TypingIndicator(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.add_circle_outline_rounded, color: c.textSecondary),
                    tooltip: 'Attach',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        suffixIcon: IconButton(
                          onPressed: () {},
                          icon: Icon(Icons.sentiment_satisfied_alt_rounded, color: c.textSecondary),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: NexaBrand.ctaGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: NexaBrand.indigo.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      tooltip: 'Send',
                    ),
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

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({required this.initialTitle});
  final String initialTitle;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final _title = TextEditingController(text: widget.initialTitle);
  DateTime? _due;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create task from message', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: _title, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Task')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.event_rounded),
            label: Text(_due == null ? 'Add deadline' : MaterialLocalizations.of(context).formatMediumDate(_due!)),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365 * 2)),
              );
              if (picked != null) setState(() => _due = picked);
            },
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Create task',
            icon: Icons.task_alt_rounded,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}

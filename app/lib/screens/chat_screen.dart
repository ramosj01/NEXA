import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/nexa_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});
  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = List<DemoMessage>.of(demoMessages);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.task_alt_rounded), tooltip: 'Tasks & decisions'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return MessageBubble(
                  text: m.body,
                  time: m.time,
                  mine: m.mine,
                  read: m.read,
                  onLongPress: () => _createTask(m),
                );
              },
            ),
          ),
          Divider(color: c.divider),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () {}, icon: Icon(Icons.add_circle_outline_rounded, color: c.textSecondary)),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        suffixIcon: IconButton(
                          onPressed: () {},
                          icon: Icon(Icons.emoji_emotions_outlined, color: c.textSecondary),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: const BoxDecoration(gradient: NexaBrand.ctaGradient, shape: BoxShape.circle),
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
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Task')),
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

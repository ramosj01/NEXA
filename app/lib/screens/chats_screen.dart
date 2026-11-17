import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/nexa_colors.dart';
import 'chat_screen.dart';

/// Smart Inbox: filterable conversation list with unread and task badges.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  static const _filters = ['All', 'Unread', 'Personal', 'Work', 'Important'];
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final chats = _filter == 'Unread' ? demoChats.where((c) => c.unread > 0).toList() : demoChats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEXA'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit_square)),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(_filters[i]),
                selected: _filters[i] == _filter,
                onSelected: (_) => setState(() => _filter = _filters[i]),
                showCheckmark: false,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (_, i) => _ChatTile(chat: chats[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});
  final DemoChat chat;

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(title: chat.name)),
      ),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: (chat.isGroup ? NexaBrand.teal : NexaBrand.violet).withValues(alpha: 0.15),
            child: chat.isGroup
                ? const Icon(Icons.groups_rounded, color: NexaBrand.teal)
                : Text(chat.name[0], style: const TextStyle(color: NexaBrand.violet, fontWeight: FontWeight.w700)),
          ),
          if (chat.online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: NexaStatus.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(chat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          if (chat.openTasks > 0) ...[
            Icon(Icons.task_alt_rounded, size: 14, color: scheme.primary),
            const SizedBox(width: 2),
            Text('${chat.openTasks}  ', style: TextStyle(color: scheme.primary, fontSize: 12)),
          ],
          Expanded(
            child: Text(chat.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary)),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(chat.time, style: TextStyle(color: chat.unread > 0 ? scheme.primary : c.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          if (chat.unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
              child: Text('${chat.unread}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

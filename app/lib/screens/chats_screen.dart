import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/nexa_colors.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

/// Chat list (Smart Inbox). Filters live in the ⋮ menu.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  InboxFilter _filter = InboxFilter.all;

  static const _labels = {
    InboxFilter.all: 'All chats',
    InboxFilter.unread: 'Unread',
    InboxFilter.personal: 'Personal',
    InboxFilter.work: 'Work',
    InboxFilter.important: 'Important',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final chats = demoChats.where((ch) => ch.matches(_filter)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEXA Chat'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded), tooltip: 'Search'),
          PopupMenuButton<Object>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v is InboxFilter) {
                setState(() => _filter = v);
              } else {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }
            },
            itemBuilder: (_) => [
              for (final e in _labels.entries)
                CheckedPopupMenuItem(value: e.key, checked: e.key == _filter, child: Text(e.value)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      floatingActionButton: _GradientFab(onPressed: () {}),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _Story(
                  label: 'Add',
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NexaBrand.indigo.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.add_rounded, size: 30, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                for (final s in demoStories)
                  _Story(
                    label: s.name,
                    child: NexaAvatar(name: s.name, size: 52, online: s.online, isGroup: s.isGroup, ring: true),
                  ),
              ],
            ),
          ),
          if (_filter != InboxFilter.all)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Text('Showing: ${_labels[_filter]}', style: TextStyle(color: c.textSecondary)),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _filter = InboxFilter.all), child: const Text('Clear')),
                ],
              ),
            ),
          for (final chat in chats) _ChatTile(chat: chat),
          if (chats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No chats here', style: TextStyle(color: c.textSecondary))),
            ),
        ],
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        children: [
          SizedBox(height: 62, width: 62, child: Center(child: child)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: NexaBrand.ctaGradient,
        boxShadow: [
          BoxShadow(color: NexaBrand.indigo.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'New chat',
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
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
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chat: chat))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            NexaAvatar(name: chat.name, online: chat.online, isGroup: chat.isGroup),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          chat.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.textSecondary, fontSize: 14),
                        ),
                      ),
                      if (chat.lastFromMe) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.done_all_rounded, size: 16, color: chat.read ? primary : c.textSecondary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chat.time, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                if (chat.unread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${chat.unread}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

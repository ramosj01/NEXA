import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/nexa_colors.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded), tooltip: 'Search'),
          IconButton(onPressed: () {}, icon: const Icon(Icons.add_rounded), tooltip: 'New group'),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(child: _ActionCard(icon: Icons.group_add_rounded, label: 'Create\nGroup', onTap: () {})),
                const SizedBox(width: 12),
                Expanded(child: _ActionCard(icon: Icons.campaign_rounded, label: 'Join\nChannel', onTap: () {})),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('My Groups', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          for (final g in demoGroups)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: NexaAvatar(name: g.name, isGroup: true),
              title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${g.members} members', style: TextStyle(color: c.textSecondary)),
              trailing: g.unread > 0
                  ? CircleAvatar(
                      radius: 11,
                      backgroundColor: primary,
                      child: Text('${g.unread}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    )
                  : Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chat: g))),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: context.nexa.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: primary, size: 30),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

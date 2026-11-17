import 'package:flutter/material.dart';

import '../main.dart' show themeMode;
import '../theme/nexa_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _online = true;

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              value: _online,
              onChanged: (v) => setState(() => _online = v),
              secondary: Icon(Icons.circle, size: 14, color: _online ? NexaStatus.success : c.textSecondary),
              title: Text(_online ? 'Online' : 'Offline'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeMode,
                    builder: (_, mode, __) => SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('System')),
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => themeMode.value = s.first,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.shield_outlined), title: const Text('Trust & Safety'), trailing: const Icon(Icons.chevron_right)),
                Divider(color: c.divider, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.auto_awesome_outlined), title: const Text('AI features (opt-in)'), subtitle: const Text('Off — nothing is sent to an AI service'), trailing: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

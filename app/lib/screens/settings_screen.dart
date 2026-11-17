import 'package:flutter/material.dart';

import '../main.dart' show themeMode;
import '../theme/nexa_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enterToSend = true;
  bool _readReceipts = true;
  bool _typingIndicator = true;

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final primary = Theme.of(context).colorScheme.primary;

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: c.textSecondary, fontSize: 13)),
        );

    Widget mode(ThemeMode m, IconData icon, Color iconColor, String label) {
      final selected = themeMode.value == m;
      return ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(
          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
          color: selected ? primary : c.textSecondary,
        ),
        onTap: () => setState(() => themeMode.value = m),
      );
    }

    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          value: value,
          onChanged: onChanged,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          header('Appearance'),
          mode(ThemeMode.light, Icons.light_mode_rounded, NexaStatus.warning, 'Light Mode'),
          mode(ThemeMode.dark, Icons.dark_mode_rounded, c.textPrimary, 'Dark Mode'),
          mode(ThemeMode.system, Icons.desktop_windows_outlined, c.textPrimary, 'Auto (System)'),
          header('Chat Settings'),
          toggle('Enter to Send', _enterToSend, (v) => setState(() => _enterToSend = v)),
          toggle('Show Read Receipts', _readReceipts, (v) => setState(() => _readReceipts = v)),
          toggle('Typing Indicator', _typingIndicator, (v) => setState(() => _typingIndicator = v)),
          header('Privacy'),
          ListTile(
            leading: Icon(Icons.block_rounded, color: c.textPrimary),
            title: const Text('Blocked Contacts', style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.verified_user_outlined, color: c.textPrimary),
            title: const Text('Two-Step Verification', style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.auto_awesome_outlined, color: c.textPrimary),
            title: const Text('AI Features', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Off — nothing is sent to an AI service', style: TextStyle(color: c.textSecondary)),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            onTap: () {},
          ),
          header('About'),
          ListTile(
            title: const Text('App Version', style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: Text('v0.1.0', style: TextStyle(color: c.textSecondary)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

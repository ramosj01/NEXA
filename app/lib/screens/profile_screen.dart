import 'package:flutter/material.dart';

import '../main.dart' show themeMode;
import '../theme/nexa_colors.dart';
import '../widgets/avatar.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;

  void _openSettings() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final c = context.nexa;
    final modeLabel = switch (themeMode.value) {
      ThemeMode.light => 'Light Mode',
      ThemeMode.dark => 'Dark Mode',
      ThemeMode.system => 'Auto',
    };

    Widget row(IconData icon, String title, {Widget? trailing, VoidCallback? onTap}) => ListTile(
          leading: Icon(icon, color: c.textPrimary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          onTap: onTap ?? () {},
        );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              Container(
                height: 270,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [NexaBrand.indigo, NexaBrand.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_rounded, color: Colors.white),
                        tooltip: 'Edit profile',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const NexaAvatar(name: 'Anna Davis', size: 92),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Anna Davis',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.circle, size: 8, color: NexaStatus.success),
                        SizedBox(width: 5),
                        Text('Online', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('About Me', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Living life one chat at a time 😊', style: TextStyle(color: c.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row(Icons.person_outline_rounded, 'My Account'),
          row(
            Icons.notifications_none_rounded,
            'Notifications',
            trailing: Switch(value: _notifications, onChanged: (v) => setState(() => _notifications = v)),
            onTap: () => setState(() => _notifications = !_notifications),
          ),
          row(Icons.lock_outline_rounded, 'Privacy & Security', onTap: _openSettings),
          row(
            Icons.palette_outlined,
            'Appearance',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(modeLabel, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ],
            ),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              setState(() {});
            },
          ),
          row(Icons.chat_bubble_outline_rounded, 'Chat Themes', onTap: _openSettings),
          row(Icons.storage_rounded, 'Data & Storage'),
          row(Icons.help_outline_rounded, 'Help & Support'),
          row(Icons.info_outline_rounded, 'About NEXA Chat'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: NexaStatus.error,
                backgroundColor: NexaStatus.error.withValues(alpha: 0.08),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {},
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/nexa_theme.dart';

/// App-wide theme mode; Profile lets the user switch it.
final themeMode = ValueNotifier(ThemeMode.system);

void main() => runApp(const NexaApp());

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'NEXA',
        debugShowCheckedModeBanner: false,
        theme: NexaTheme.light(),
        darkTheme: NexaTheme.dark(),
        themeMode: mode,
        home: const HomeShell(),
      ),
    );
  }
}

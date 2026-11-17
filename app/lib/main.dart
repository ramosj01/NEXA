import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'assistant/background_service.dart';
import 'assistant/jarvis_controller.dart';
import 'screens/home_shell.dart';
import 'theme/nexa_theme.dart';

/// App-wide theme mode; Profile lets the user switch it.
final themeMode = ValueNotifier(ThemeMode.system);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  JarvisBackground.init();
  runApp(const NexaApp());
  // Restores the wake word / background service the user left switched on.
  jarvis.init();
}

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
        home: const WithForegroundTask(child: HomeShell()),
      ),
    );
  }
}

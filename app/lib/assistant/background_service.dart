import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'assistant_api.dart';

/// Keeps Jarvis alive while NEXA is in the background.
///
/// On Android this is a foreground service (a persistent notification) of
/// type `microphone|dataSync`. It does two things:
///   * keeps the app process alive, so the "Jarvis" wake word engine, which
///     runs in the main isolate, keeps listening with the screen off;
///   * every few minutes, checks the inbox (no AI call, so it costs nothing)
///     and shows "2 waiting on you · 3 open tasks" in the notification.
/// The notification has a "Talk" button that opens Jarvis listening.
///
/// iOS does not allow an app to keep the microphone open in the background
/// for a wake word, so there Jarvis works while the app is open.
class JarvisBackground {
  static const _serviceId = 4242;
  static const talkButtonId = 'talk';
  static const stopButtonId = 'stop';

  /// Messages from the service isolate to the UI isolate.
  static const msgTalk = 'talk';
  static const msgDigest = 'digest';

  static bool get supported => Platform.isAndroid;

  static void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'jarvis_service',
        channelName: 'Jarvis assistant',
        channelDescription: 'Shown while Jarvis is running in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Inbox check every 5 minutes.
        eventAction: ForegroundTaskEventAction.repeat(5 * 60 * 1000),
        // Android 15 forbids starting microphone services from BOOT_COMPLETED.
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  /// Asks for what the service needs. Returns false if notifications are denied.
  static Future<bool> requestPermissions() async {
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    // Needed to bring Jarvis to the front when the wake word is heard while
    // another app is open (Android blocks background activity starts otherwise).
    if (!await FlutterForegroundTask.canDrawOverlays) {
      await FlutterForegroundTask.openSystemAlertWindowSettings();
    }
    return await FlutterForegroundTask.checkNotificationPermission() == NotificationPermission.granted;
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  static Future<bool> start({required bool wakeWord}) async {
    if (!supported) return false;
    await FlutterForegroundTask.saveData(key: 'apiUrl', value: AssistantConfig.apiUrl);
    await FlutterForegroundTask.saveData(key: 'token', value: AssistantConfig.token);
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [
        if (wakeWord) ForegroundServiceTypes.microphone,
        ForegroundServiceTypes.dataSync,
      ],
      notificationTitle: wakeWord ? 'Jarvis is listening' : 'Jarvis is on standby',
      notificationText: wakeWord ? 'Say "Jarvis" or tap Talk' : 'Tap Talk to speak',
      notificationButtons: const [
        NotificationButton(id: talkButtonId, text: 'Talk'),
        NotificationButton(id: stopButtonId, text: 'Turn off'),
      ],
      callback: _startCallback,
    );
    return result is ServiceRequestSuccess;
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_JarvisTaskHandler());
}

/// Runs in the service's own isolate.
class _JarvisTaskHandler extends TaskHandler {
  AssistantApi? _api;
  String? _lastSummary;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final url = await FlutterForegroundTask.getData<String>(key: 'apiUrl');
    final token = await FlutterForegroundTask.getData<String>(key: 'token');
    _api = AssistantApi(baseUrl: url, token: token);
    await _refresh();
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _refresh();

  Future<void> _refresh() async {
    final api = _api;
    if (api == null) return;
    try {
      final d = await api.digest();
      if (d.summary == _lastSummary) return;
      _lastSummary = d.summary;
      FlutterForegroundTask.updateService(notificationText: d.summary);
      FlutterForegroundTask.sendDataToMain({'type': JarvisBackground.msgDigest, 'summary': d.summary});
    } catch (_) {
      // Offline: keep the last notification text and try again next tick.
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == JarvisBackground.talkButtonId) {
      FlutterForegroundTask.launchApp();
      FlutterForegroundTask.sendDataToMain({'type': JarvisBackground.msgTalk});
    } else if (id == JarvisBackground.stopButtonId) {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _api?.close();
  }
}

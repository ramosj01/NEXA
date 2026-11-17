import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'assistant_api.dart';
import 'background_service.dart';

enum JarvisState { idle, wakeListening, listening, thinking, speaking }

class JarvisEntry {
  JarvisEntry.user(this.text) : role = 'user', actions = const [];
  JarvisEntry.assistant(this.text, [this.actions = const []]) : role = 'assistant';
  final String role;
  final String text;
  final List<AssistantAction> actions;
}

/// The assistant's brain on the device: wake word, speech in, speech out.
///
/// The microphone can only be used by one engine at a time, so the wake word
/// engine is paused while speech recognition runs and resumed afterwards.
class JarvisController extends ChangeNotifier with WidgetsBindingObserver {
  JarvisController({AssistantApi? api}) : _api = api ?? AssistantApi();

  final AssistantApi _api;
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  PorcupineManager? _porcupine;

  JarvisState _state = JarvisState.idle;
  JarvisState get state => _state;

  final List<JarvisEntry> transcript = [];
  String partial = '';
  double soundLevel = 0;
  String? error;
  String? digest;

  bool wakeWordEnabled = false;
  bool backgroundEnabled = false;
  bool _sttReady = false;
  bool _initialised = false;

  /// Fires when something outside the Jarvis screen (wake word, notification
  /// button) wants Jarvis shown; the home shell switches to its tab.
  final showRequests = ValueNotifier<int>(0);

  static const _prefWake = 'jarvis.wakeWord';
  static const _prefBackground = 'jarvis.background';
  static const _maxHistory = 20;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onServiceData);

    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(0.95);

    final prefs = await SharedPreferences.getInstance();
    wakeWordEnabled = AssistantConfig.hasWakeWord && (prefs.getBool(_prefWake) ?? false);
    backgroundEnabled = JarvisBackground.supported && (prefs.getBool(_prefBackground) ?? false);
    // Wake word first: it obtains the microphone permission, which Android 14+
    // requires before a microphone-type service may start.
    if (wakeWordEnabled) await _startWakeWord();
    if (backgroundEnabled && !await JarvisBackground.isRunning) {
      // Only (re)start the service from the foreground, as Android requires
      // for microphone services; init() runs at app start, which qualifies.
      await JarvisBackground.start(wakeWord: wakeWordEnabled);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ settings

  Future<void> setWakeWord(bool on) async {
    if (on && !AssistantConfig.hasWakeWord) return;
    wakeWordEnabled = on;
    (await SharedPreferences.getInstance()).setBool(_prefWake, on);
    if (on) {
      await _startWakeWord();
    } else {
      await _stopWakeWord(release: true);
    }
    if (backgroundEnabled) {
      // The service type (microphone or not) depends on the wake word.
      await JarvisBackground.stop();
      await JarvisBackground.start(wakeWord: on);
    }
    notifyListeners();
  }

  Future<void> setBackground(bool on) async {
    if (on && !await JarvisBackground.requestPermissions()) {
      error = 'Allow notifications so Jarvis can run in the background.';
      notifyListeners();
      return;
    }
    backgroundEnabled = on && await JarvisBackground.start(wakeWord: wakeWordEnabled);
    if (!on) await JarvisBackground.stop();
    (await SharedPreferences.getInstance()).setBool(_prefBackground, backgroundEnabled);
    if (on && !backgroundEnabled) error = 'Android refused to start the background service.';
    notifyListeners();
  }

  // ----------------------------------------------------------------- wake word

  Future<void> _startWakeWord() async {
    try {
      _porcupine ??= await PorcupineManager.fromBuiltInKeywords(
        AssistantConfig.picovoiceAccessKey,
        [BuiltInKeyword.JARVIS],
        (_) => _onWakeWord(),
        errorCallback: (e) => _fail('Wake word error: ${e.message}'),
      );
      await _porcupine!.start();
      if (_state == JarvisState.idle) _setState(JarvisState.wakeListening);
    } on PorcupineException catch (e) {
      wakeWordEnabled = false;
      _fail('Wake word unavailable: ${e.message}');
    }
  }

  Future<void> _stopWakeWord({bool release = false}) async {
    final p = _porcupine;
    if (p == null) return;
    await p.stop();
    if (release) {
      await p.delete();
      _porcupine = null;
      if (_state == JarvisState.wakeListening) _setState(JarvisState.idle);
    }
  }

  void _onWakeWord() {
    if (_state == JarvisState.listening || _state == JarvisState.thinking) return;
    // In the background, bring NEXA forward (needs "display over other apps").
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      FlutterForegroundTask.launchApp();
    }
    showRequests.value++;
    listen();
  }

  void _onServiceData(Object data) {
    if (data is! Map) return;
    switch (data['type']) {
      case JarvisBackground.msgTalk:
        showRequests.value++;
        // Give the activity a moment to come forward before opening the mic.
        Future.delayed(const Duration(milliseconds: 600), listen);
      case JarvisBackground.msgDigest:
        digest = data['summary'] as String?;
        notifyListeners();
    }
  }

  // ------------------------------------------------------------- conversation

  /// Start listening for a request (tap on the orb, wake word, notification).
  Future<void> listen() async {
    if (_state == JarvisState.listening) return stopListening();
    await _tts.stop();
    await _stopWakeWord();
    error = null;

    if (!_sttReady) {
      _sttReady = await _stt.initialize(
        onError: (e) => _fail(e.permanent ? "I couldn't hear that." : null),
        onStatus: (_) {},
      );
      if (!_sttReady) {
        _fail('Speech recognition is not available. Check the microphone permission.');
        return _resumeIdle();
      }
    }

    partial = '';
    _setState(JarvisState.listening);
    await _stt.listen(
      onResult: _onSpeech,
      onSoundLevelChange: (l) {
        soundLevel = l;
        notifyListeners();
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  void _onSpeech(SpeechRecognitionResult r) {
    partial = r.recognizedWords;
    notifyListeners();
    if (r.finalResult) {
      final text = partial.trim();
      partial = '';
      if (text.isEmpty) {
        _resumeIdle();
      } else {
        send(text);
      }
    }
  }

  /// Send a request (spoken, or typed in the Jarvis screen).
  Future<void> send(String text) async {
    text = _stripWakeWord(text);
    if (text.isEmpty) return _resumeIdle();
    final history = [
      for (final e in transcript.reversed.take(_maxHistory).toList().reversed) AssistantTurn(e.role, e.text),
    ];
    transcript.add(JarvisEntry.user(text));
    _setState(JarvisState.thinking);

    String reply;
    try {
      final r = await _api.ask(text, history);
      reply = r.text;
      transcript.add(JarvisEntry.assistant(reply, r.actions));
    } on AssistantException catch (e) {
      reply = e.spokenMessage;
      transcript.add(JarvisEntry.assistant(reply));
    }
    await speak(reply);
  }

  Future<void> speak(String text) async {
    _setState(JarvisState.speaking);
    await _tts.speak(text);
    await _resumeIdle();
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _resumeIdle();
  }

  Future<void> _resumeIdle() async {
    if (wakeWordEnabled) {
      await _startWakeWord();
      _setState(JarvisState.wakeListening);
    } else {
      _setState(JarvisState.idle);
    }
  }

  static final _wakePrefix = RegExp(r'^\s*(hey\s+|ok(ay)?\s+)?jarvis[\s,.!]*', caseSensitive: false);
  static String _stripWakeWord(String s) => s.replaceFirst(_wakePrefix, '').trim();

  void clearTranscript() {
    transcript.clear();
    notifyListeners();
  }

  void _setState(JarvisState s) {
    _state = s;
    if (s != JarvisState.listening) soundLevel = 0;
    notifyListeners();
  }

  void _fail(String? message) {
    if (message != null) error = message;
    if (_state == JarvisState.listening) _resumeIdle();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Without the background service, Android may kill a backgrounded app, and
    // keeping the mic open would be invisible to the user: pause the wake word.
    if (!wakeWordEnabled || backgroundEnabled) return;
    if (state == AppLifecycleState.paused) {
      _stopWakeWord();
    } else if (state == AppLifecycleState.resumed && _state == JarvisState.wakeListening) {
      _startWakeWord();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onServiceData);
    _porcupine?.delete();
    _stt.cancel();
    _tts.stop();
    _api.close();
    showRequests.dispose();
    super.dispose();
  }
}

/// App-wide instance.
final jarvis = JarvisController();

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa/assistant/assistant_api.dart';
import 'package:nexa/assistant/jarvis_controller.dart';
import 'package:nexa/screens/jarvis_screen.dart';
import 'package:nexa/theme/nexa_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async {
        if (call.method == 'speak') spoken.add(call.arguments as String);
        return 1;
      },
    );
  });

  test('digest summarises the inbox for the notification', () async {
    final api = AssistantApi(
      baseUrl: 'http://nexa.test',
      token: 'dev:me',
      client: MockClient((req) async => http.Response(
            req.url.path == '/inbox'
                ? jsonEncode([
                    {'awaiting_my_reply': true, 'unread_count': 2},
                    {'awaiting_my_reply': false, 'unread_count': 1},
                    {'awaiting_my_reply': false, 'unread_count': 0},
                  ])
                : jsonEncode([{}, {}, {}]),
            200,
          )),
    );
    expect((await api.digest()).summary, '1 waiting on you · 2 unread · 3 open tasks');
  });

  testWidgets('a request goes to the server, shows actions and is spoken', (tester) async {
    late Map<String, dynamic> sent;
    final api = AssistantApi(
      baseUrl: 'http://nexa.test',
      token: 'dev:me',
      client: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer dev:me');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'reply': 'Bob is waiting on the deck. I added a task.',
            'actions': [
              {'tool': 'create_task', 'ok': true, 'summary': 'created task “Send the deck” in Project'},
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final controller = JarvisController(api: api);

    await tester.pumpWidget(MaterialApp(theme: NexaTheme.light(), home: JarvisScreen(controller: controller)));
    expect(find.text('Tap to talk'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Jarvis, what is waiting on me?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The wake word is stripped before the request is sent.
    expect(sent['text'], 'what is waiting on me?');
    expect(find.text('Bob is waiting on the deck. I added a task.'), findsOneWidget);
    expect(find.text('created task “Send the deck” in Project'), findsOneWidget);
    expect(spoken, ['Bob is waiting on the deck. I added a task.']);
    expect(controller.state, JarvisState.idle);

    // Unmount so the orb's repeating animation stops before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('server unreachable is spoken, not thrown', (tester) async {
    final controller = JarvisController(
      api: AssistantApi(
        baseUrl: 'http://nexa.test',
        client: MockClient((_) async => throw http.ClientException('offline')),
      ),
    );
    await controller.send('hello');
    expect(spoken.single, contains("can't reach"));
  });
}

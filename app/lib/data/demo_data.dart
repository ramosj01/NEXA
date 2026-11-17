/// In-memory sample data so the UI runs before the API client is wired up.
class DemoMessage {
  DemoMessage(this.body, this.time, {required this.mine, this.read = false});
  final String body;
  final String time;
  final bool mine;
  final bool read;
}

class DemoChat {
  const DemoChat({
    required this.name,
    required this.preview,
    required this.time,
    this.unread = 0,
    this.isGroup = false,
    this.online = false,
    this.openTasks = 0,
  });
  final String name;
  final String preview;
  final String time;
  final int unread;
  final bool isGroup;
  final bool online;
  final int openTasks;
}

const demoChats = [
  DemoChat(
    name: 'Project Team',
    preview: 'We need to finish the proposal by Friday.',
    time: '9:41 AM',
    unread: 3,
    isGroup: true,
    openTasks: 2,
  ),
  DemoChat(name: 'Maya', preview: 'Hello! How are you?', time: '9:24 AM', unread: 1, online: true),
  DemoChat(name: 'Design Guild', preview: 'Poll: Meeting on Tue or Wed?', time: 'Yesterday', isGroup: true),
  DemoChat(name: 'Leo', preview: 'Sent the files 👍', time: 'Mon'),
];

final demoMessages = [
  DemoMessage('Hello! How are you?', '9:24 AM', mine: false),
  DemoMessage("I'm good. Thanks! 😊", '9:25 AM', mine: true, read: true),
  DemoMessage('We need to finish the project proposal by Friday.', '9:40 AM', mine: false),
  DemoMessage('Submit the report Friday', '9:41 AM', mine: true),
];

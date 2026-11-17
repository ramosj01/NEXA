/// In-memory sample data so the UI runs before the API client is wired up.
library;

enum MessageKind { text, image, voice }

enum InboxFilter { all, unread, personal, work, important }

class DemoMessage {
  DemoMessage(
    this.body,
    this.time, {
    required this.mine,
    this.read = false,
    this.kind = MessageKind.text,
    this.hearts = 0,
    this.duration,
  });

  final String body;
  final String time;
  final bool mine;
  final bool read;
  final MessageKind kind;
  final int hearts;
  final String? duration;
}

class DemoChat {
  const DemoChat({
    required this.name,
    required this.preview,
    required this.time,
    this.unread = 0,
    this.isGroup = false,
    this.online = false,
    this.lastFromMe = false,
    this.read = false,
    this.members = 0,
    this.category = InboxFilter.personal,
  });

  final String name;
  final String preview;
  final String time;
  final int unread;
  final bool isGroup;
  final bool online;
  final bool lastFromMe;
  final bool read;
  final int members;
  final InboxFilter category;

  bool matches(InboxFilter f) => switch (f) {
        InboxFilter.all => true,
        InboxFilter.unread => unread > 0,
        _ => category == f,
      };
}

const demoStories = [
  DemoChat(name: 'Sarah', preview: '', time: '', online: true),
  DemoChat(name: 'Mike', preview: '', time: ''),
  DemoChat(name: 'Team', preview: '', time: '', isGroup: true),
];

const demoChats = [
  DemoChat(
    name: 'Project Team',
    preview: 'Great update!',
    time: '9:32 AM',
    unread: 3,
    isGroup: true,
    members: 24,
    lastFromMe: true,
    category: InboxFilter.work,
  ),
  DemoChat(name: 'Sarah Johnson', preview: 'See you later!', time: '8:45 AM', online: true),
  DemoChat(
    name: 'Family Group',
    preview: 'Dinner tonight?',
    time: 'Yesterday',
    unread: 1,
    isGroup: true,
    members: 8,
    category: InboxFilter.important,
  ),
  DemoChat(
    name: 'Mike Chen',
    preview: 'Thanks!',
    time: 'Yesterday',
    online: true,
    lastFromMe: true,
    read: true,
  ),
  DemoChat(
    name: 'Work Friends',
    preview: "Let's catch up soon.",
    time: 'Sat',
    isGroup: true,
    members: 12,
    category: InboxFilter.work,
  ),
  DemoChat(name: 'Anna Davis', preview: 'Sounds good 👍', time: 'Fri', online: true),
];

const demoGroups = [
  DemoChat(name: 'Project Team', preview: '', time: '', isGroup: true, members: 24, unread: 3),
  DemoChat(name: 'Family Group', preview: '', time: '', isGroup: true, members: 8),
  DemoChat(name: 'Work Friends', preview: '', time: '', isGroup: true, members: 12),
  DemoChat(name: 'Travel Buddies', preview: '', time: '', isGroup: true, members: 10),
  DemoChat(name: 'Fitness Club', preview: '', time: '', isGroup: true, members: 15),
];

List<DemoMessage> demoMessagesFor(DemoChat chat) {
  if (chat.name == 'Project Team') {
    return [
      DemoMessage('Morning all! Quick sync on the proposal.', '9:20 AM', mine: false),
      DemoMessage(
        'We need to finish the project proposal by Friday. John handles the budget '
        'and Sarah handles the presentation.',
        '9:24 AM',
        mine: false,
      ),
      DemoMessage('On it. Long-press any message to turn it into a task ✅', '9:30 AM', mine: true, read: true),
      DemoMessage('Great update!', '9:32 AM', mine: true, read: true),
    ];
  }
  return [
    DemoMessage('Hey! How are you? 😊', '9:12 AM', mine: false),
    DemoMessage("I'm good. Thanks!", '9:15 AM', mine: true, read: true),
    DemoMessage('Beach photo', '9:18 AM', mine: true, read: true, kind: MessageKind.image, hearts: 1),
    DemoMessage('Nice! Where is this?', '9:20 AM', mine: false),
    DemoMessage('Boracay 🌴', '9:22 AM', mine: true, read: true),
    DemoMessage('Voice message', '9:25 AM', mine: true, read: true, kind: MessageKind.voice, duration: '0:12'),
  ];
}

import 'package:flutter/material.dart';

import '../theme/nexa_colors.dart';

const _gradients = [
  [NexaBrand.indigo, NexaBrand.violet],
  [NexaBrand.sky, NexaBrand.indigo],
  [NexaBrand.teal, NexaBrand.sky],
  [NexaBrand.violet, NexaStatus.purple],
  [NexaStatus.warning, NexaStatus.error],
  [NexaStatus.purple, NexaBrand.sky],
];

/// Gradient avatar with initials (or a group icon) and an optional online dot.
/// Stands in for profile photos until uploads exist.
class NexaAvatar extends StatelessWidget {
  const NexaAvatar({
    super.key,
    required this.name,
    this.size = 52,
    this.online = false,
    this.isGroup = false,
    this.ring = false,
  });

  final String name;
  final double size;
  final bool online;
  final bool isGroup;

  /// Story-style gradient ring around the avatar.
  final bool ring;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final colors = isGroup
        ? const [NexaBrand.indigo, NexaBrand.violet]
        : _gradients[name.codeUnits.fold<int>(0, (a, b) => a + b) % _gradients.length];
    final bg = context.nexa.background;

    Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: isGroup
          ? Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.5)
          : Text(
              _initials,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * 0.36),
            ),
    );

    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: NexaBrand.ctaGradient),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: avatar,
        ),
      );
    }

    if (!online) return avatar;
    final dot = size * 0.26;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: ring ? 4 : 0,
          bottom: ring ? 4 : 0,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: NexaStatus.success,
              shape: BoxShape.circle,
              border: Border.all(color: bg, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

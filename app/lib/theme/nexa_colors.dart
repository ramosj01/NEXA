import 'package:flutter/material.dart';

/// NEXA brand palette — the single source of truth for colors.
/// Mirrors design/tokens.json.
abstract final class NexaBrand {
  static const indigo = Color(0xFF5865F2);
  static const violet = Color(0xFF8B5CF6);
  static const sky = Color(0xFF0EA5E9);
  static const teal = Color(0xFF14B8A6);

  /// Primary call-to-action gradient (e.g. "Send Message").
  static const ctaGradient = LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

abstract final class NexaStatus {
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);
  static const purple = Color(0xFFA855F7);
}

/// Mode-specific colors, exposed to widgets as a ThemeExtension:
/// `Theme.of(context).extension<NexaColors>()!` or `context.nexa`.
@immutable
class NexaColors extends ThemeExtension<NexaColors> {
  const NexaColors({
    required this.background,
    required this.surface,
    required this.bubbleReceived,
    required this.bubbleSent,
    required this.onBubbleReceived,
    required this.onBubbleSent,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });

  final Color background;
  final Color surface;
  final Color bubbleReceived;
  final Color bubbleSent;
  final Color onBubbleReceived;
  final Color onBubbleSent;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  static const light = NexaColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F7FB),
    bubbleReceived: Color(0xFFE8EDFF),
    bubbleSent: Color(0xFF5865F2),
    onBubbleReceived: Color(0xFF1F2937),
    onBubbleSent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF6B7280),
    divider: Color(0xFFE5E7EB),
  );

  static const dark = NexaColors(
    background: Color(0xFF101321),
    surface: Color(0xFF1C2030),
    bubbleReceived: Color(0xFF343C70),
    bubbleSent: Color(0xFF6366F1),
    onBubbleReceived: Color(0xFFF8FAFC),
    onBubbleSent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    divider: Color(0xFF2A2F45),
  );

  @override
  NexaColors copyWith({
    Color? background,
    Color? surface,
    Color? bubbleReceived,
    Color? bubbleSent,
    Color? onBubbleReceived,
    Color? onBubbleSent,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
  }) =>
      NexaColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        bubbleReceived: bubbleReceived ?? this.bubbleReceived,
        bubbleSent: bubbleSent ?? this.bubbleSent,
        onBubbleReceived: onBubbleReceived ?? this.onBubbleReceived,
        onBubbleSent: onBubbleSent ?? this.onBubbleSent,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        divider: divider ?? this.divider,
      );

  @override
  NexaColors lerp(NexaColors? other, double t) {
    if (other == null) return this;
    return NexaColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      bubbleReceived: Color.lerp(bubbleReceived, other.bubbleReceived, t)!,
      bubbleSent: Color.lerp(bubbleSent, other.bubbleSent, t)!,
      onBubbleReceived: Color.lerp(onBubbleReceived, other.onBubbleReceived, t)!,
      onBubbleSent: Color.lerp(onBubbleSent, other.onBubbleSent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension NexaThemeX on BuildContext {
  NexaColors get nexa => Theme.of(this).extension<NexaColors>()!;
}

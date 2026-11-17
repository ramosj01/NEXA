import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/theme/nexa_colors.dart';

void main() {
  test('palette matches the brand sheet', () {
    expect(NexaBrand.indigo.toARGB32(), 0xFF5865F2);
    expect(NexaColors.light.bubbleSent.toARGB32(), 0xFF5865F2);
    expect(NexaColors.dark.background.toARGB32(), 0xFF101321);
  });
}

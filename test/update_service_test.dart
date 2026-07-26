import 'package:flutter_test/flutter_test.dart';
import 'package:owenote/services/update_service.dart';

void main() {
  group('isNewerVersion', () {
    test('detects newer major, minor, and patch releases', () {
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(isNewerVersion('1.2.0', '1.1.9'), isTrue);
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
    });

    test('rejects equal and older releases', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
    });

    test('ignores build metadata', () {
      expect(isNewerVersion('1.1.0', '1.0.0+42'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.0+42'), isFalse);
    });
  });
}

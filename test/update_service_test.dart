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
  test('release notes keep changes and separate the full changelog link', () {
    final fallback = Uri.parse('https://example.com/release');
    final parsed = parseReleaseNotes('''
### Changed

- Downloads continue in the background.

[Full changelog](https://example.com/compare)
''', fallback);

    expect(parsed.notes, contains('Downloads continue in the background.'));
    expect(parsed.notes, isNot(contains('Full changelog')));
    expect(parsed.changelogUrl, Uri.parse('https://example.com/compare'));
  });

  test('download status exposes determinate progress', () {
    final status = UpdateDownloadStatus.fromMap(const {
      'phase': 'downloading',
      'version': '1.0.2',
      'downloadedBytes': 25,
      'totalBytes': 100,
    });

    expect(status.phase, UpdateDownloadPhase.downloading);
    expect(status.version, '1.0.2');
    expect(status.progress, 0.25);
  });

  test('release notes use the release page when no changelog link exists', () {
    final fallback = Uri.parse('https://example.com/release');
    final parsed = parseReleaseNotes('- One fix', fallback);

    expect(parsed.changelogUrl, fallback);
  });
}

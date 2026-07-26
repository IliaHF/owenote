import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/ledger_repository.dart';

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String version;
  final Uri downloadUrl;
  final String releaseNotes;
}

class UpdateService {
  UpdateService(this._repository, {HttpClient? client})
    : _client = client ?? HttpClient();

  static const _channel = MethodChannel('com.iliahf.owenote/updater');
  static final _latestRelease = Uri.https(
    'api.github.com',
    '/repos/IliaHF/owenote/releases/latest',
  );
  static const _checkInterval = Duration(days: 1);

  final LedgerRepository _repository;
  final HttpClient _client;

  Future<String> currentVersion() async =>
      (await _channel.invokeMethod<String>('getVersion')) ?? 'Unknown';

  Future<AppUpdate?> checkForUpdate({bool force = false}) async {
    if (!Platform.isAndroid) return null;

    final now = DateTime.now().toUtc();
    if (!force) {
      final lastCheck = await _repository.lastUpdateCheck();
      if (lastCheck != null &&
          now.difference(lastCheck.toUtc()) < _checkInterval) {
        return null;
      }
    }

    // Record attempts as well as successful checks so an offline device does not
    // repeatedly contact GitHub every time the app is opened.
    await _repository.setLastUpdateCheck(now);

    final request = await _client.getUrl(_latestRelease);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'OweNote Android updater');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub returned ${response.statusCode} while checking for updates.',
        uri: _latestRelease,
      );
    }

    final release = jsonDecode(body) as Map<String, dynamic>;
    final tag = (release['tag_name'] as String? ?? '').trim();
    final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
    final installedVersion = await currentVersion();
    if (!isNewerVersion(latestVersion, installedVersion)) return null;

    final assets = (release['assets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final matchingAssets = assets.where(
      (asset) => asset['name'] == 'OweNote.apk',
    );
    final apk = matchingAssets.isEmpty ? null : matchingAssets.first;
    final url = Uri.tryParse(apk?['browser_download_url'] as String? ?? '');
    if (url == null) {
      throw const FormatException(
        'The latest GitHub release does not contain OweNote.apk.',
      );
    }

    return AppUpdate(
      version: latestVersion,
      downloadUrl: url,
      releaseNotes: (release['body'] as String? ?? '').trim(),
    );
  }

  Future<void> downloadAndInstall(AppUpdate update) async {
    final directory = await getTemporaryDirectory();
    final apk = File(p.join(directory.path, 'OweNote-${update.version}.apk'));
    final request = await _client.getUrl(update.downloadUrl);
    request.headers.set(HttpHeaders.userAgentHeader, 'OweNote Android updater');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'GitHub returned ${response.statusCode} while downloading the update.',
        uri: update.downloadUrl,
      );
    }
    final sink = apk.openWrite();
    try {
      await response.pipe(sink);
    } catch (_) {
      await sink.close();
      if (await apk.exists()) await apk.delete();
      rethrow;
    }
    await _channel.invokeMethod<void>('installApk', {'path': apk.path});
  }
}

bool isNewerVersion(String candidate, String current) {
  List<int> parts(String value) {
    final normalized = value.split('+').first.split('-').first;
    return normalized
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  final candidateParts = parts(candidate);
  final currentParts = parts(current);
  final length = candidateParts.length > currentParts.length
      ? candidateParts.length
      : currentParts.length;
  for (var index = 0; index < length; index++) {
    final next = index < candidateParts.length ? candidateParts[index] : 0;
    final installed = index < currentParts.length ? currentParts[index] : 0;
    if (next != installed) return next > installed;
  }
  return false;
}

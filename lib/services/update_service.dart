import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/ledger_repository.dart';

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.fullChangelogUrl,
  });

  final String version;
  final Uri downloadUrl;
  final String releaseNotes;
  final Uri fullChangelogUrl;
}

class ParsedReleaseNotes {
  const ParsedReleaseNotes({required this.notes, required this.changelogUrl});

  final String notes;
  final Uri changelogUrl;
}

ParsedReleaseNotes parseReleaseNotes(String body, Uri fallbackUrl) {
  final fullChangelogPattern = RegExp(
    r'\[Full changelog\]\(([^)]+)\)',
    caseSensitive: false,
  );
  final changelogMatch = fullChangelogPattern.firstMatch(body);
  return ParsedReleaseNotes(
    notes: body.replaceAll(fullChangelogPattern, '').trim(),
    changelogUrl: _parseHttpUri(changelogMatch?.group(1)) ?? fallbackUrl,
  );
}

Uri? _parseHttpUri(String? value) {
  final uri = Uri.tryParse(value ?? '');
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
      ? uri
      : null;
}

Map<String, dynamic>? selectReleaseApkAsset(
  List<Map<String, dynamic>> assets,
  String version,
) {
  for (final name in ['OweNote-$version.apk', 'OweNote.apk']) {
    for (final asset in assets) {
      if (asset['name'] == name) return asset;
    }
  }
  return null;
}

enum UpdateDownloadPhase { idle, downloading, ready, failed }

class UpdateDownloadStatus {
  const UpdateDownloadStatus({
    required this.phase,
    this.version,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  static const idle = UpdateDownloadStatus(phase: UpdateDownloadPhase.idle);

  final UpdateDownloadPhase phase;
  final String? version;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  double? get progress => totalBytes > 0
      ? (downloadedBytes / totalBytes).clamp(0, 1).toDouble()
      : null;

  factory UpdateDownloadStatus.fromMap(Map<Object?, Object?> map) {
    final phaseName = map['phase'] as String? ?? 'idle';
    return UpdateDownloadStatus(
      phase: UpdateDownloadPhase.values.firstWhere(
        (phase) => phase.name == phaseName,
        orElse: () => UpdateDownloadPhase.idle,
      ),
      version: map['version'] as String?,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      error: map['error'] as String?,
    );
  }
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
  final _downloadStatuses = StreamController<UpdateDownloadStatus>.broadcast();
  UpdateDownloadStatus _downloadStatus = UpdateDownloadStatus.idle;
  Timer? _pollTimer;
  bool _refreshing = false;

  Stream<UpdateDownloadStatus> get downloadStatuses async* {
    yield _downloadStatus;
    yield* _downloadStatuses.stream;
  }

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
    final apk = selectReleaseApkAsset(assets, latestVersion);
    final url = _parseHttpUri(apk?['browser_download_url'] as String?);
    if (url == null) {
      throw const FormatException(
        'The latest GitHub release does not contain an OweNote APK.',
      );
    }

    final releaseBody = (release['body'] as String? ?? '').trim();
    final releasePage =
        _parseHttpUri(release['html_url'] as String?) ??
        Uri.https('github.com', '/IliaHF/owenote/releases/tag/$tag');
    final parsedNotes = parseReleaseNotes(releaseBody, releasePage);

    return AppUpdate(
      version: latestVersion,
      downloadUrl: url,
      releaseNotes: parsedNotes.notes,
      fullChangelogUrl: parsedNotes.changelogUrl,
    );
  }

  Future<UpdateDownloadStatus> startUpdate(AppUpdate update) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'startDownload',
      {'url': update.downloadUrl.toString(), 'version': update.version},
    );
    final status = UpdateDownloadStatus.fromMap(result ?? const {});
    _emit(status);
    if (status.phase == UpdateDownloadPhase.ready) {
      await installDownloadedUpdate();
    } else if (status.phase == UpdateDownloadPhase.downloading) {
      _startPolling();
    }
    return status;
  }

  Future<void> installDownloadedUpdate() =>
      _channel.invokeMethod<void>('installDownloadedUpdate');

  Future<void> openFullChangelog(Uri url) =>
      _channel.invokeMethod<void>('openUrl', {'url': url.toString()});

  Future<UpdateDownloadStatus> refreshDownloadStatus() async {
    if (_refreshing || !Platform.isAndroid) return _downloadStatus;
    _refreshing = true;
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getDownloadStatus',
      );
      final status = UpdateDownloadStatus.fromMap(result ?? const {});
      _emit(status);
      if (status.phase == UpdateDownloadPhase.downloading) _startPolling();
      return status;
    } finally {
      _refreshing = false;
    }
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => refreshDownloadStatus(),
    );
  }

  void _emit(UpdateDownloadStatus status) {
    _downloadStatus = status;
    if (!_downloadStatuses.isClosed) _downloadStatuses.add(status);
    if (status.phase != UpdateDownloadPhase.downloading) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _client.close(force: true);
    _downloadStatuses.close();
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

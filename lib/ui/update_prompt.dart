import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization.dart';

import '../providers.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

Future<void> checkAndOfferUpdate(
  BuildContext context,
  WidgetRef ref, {
  required bool manual,
}) async {
  try {
    final service = ref.read(updateServiceProvider);
    final update = await service.checkForUpdate(force: manual);
    if (!context.mounted) return;
    if (update == null) {
      if (manual) showMessage(context, context.l10n.text('upToDate'));
      return;
    }

    final install = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded),
        title: Text(
          context.l10n.text('updateAvailable', {'version': update.version}),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: _ReleaseNotes(
              notes: update.releaseNotes,
              onOpenFullChangelog: () =>
                  service.openFullChangelog(update.fullChangelogUrl),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.text('later')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.text('updateNow')),
          ),
        ],
      ),
    );
    if (install != true || !context.mounted) return;

    final status = await service.startUpdate(update);
    if (context.mounted && status.phase == UpdateDownloadPhase.downloading) {
      showMessage(
        context,
        context.l10n.text('downloadingUpdate', {'version': update.version}),
      );
    }
  } catch (error) {
    if (manual && context.mounted) {
      showMessage(context, friendlyError(context, error));
    }
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.notes, required this.onOpenFullChangelog});

  final String notes;
  final VoidCallback onOpenFullChangelog;

  @override
  Widget build(BuildContext context) {
    final lines = notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isEmpty)
          Text(context.l10n.text('updateReadyMessage'))
        else
          ...lines.map((line) {
            if (line.startsWith('### ')) {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  line.substring(4),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              );
            }
            if (line.startsWith('- ')) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(line.substring(2))),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(line),
            );
          }),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onOpenFullChangelog,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(context.l10n.text('fullChangelog')),
        ),
      ],
    );
  }
}

class UpdateDownloadStatusTile extends ConsumerWidget {
  const UpdateDownloadStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(updateDownloadStatusProvider).value ??
        UpdateDownloadStatus.idle;
    if (status.phase == UpdateDownloadPhase.idle) {
      return const SizedBox.shrink();
    }

    if (status.phase == UpdateDownloadPhase.ready) {
      return ListTile(
        minTileHeight: 72,
        leading: const Icon(
          Icons.download_done_rounded,
          color: AppColors.positive,
        ),
        title: Text(
          context.l10n.text('updateReady'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          context.l10n.text('updateDownloaded', {
            'version': status.version ?? '',
          }),
        ),
        trailing: FilledButton(
          onPressed: () =>
              ref.read(updateServiceProvider).installDownloadedUpdate(),
          child: Text(context.l10n.text('install')),
        ),
      );
    }

    if (status.phase == UpdateDownloadPhase.failed) {
      return ListTile(
        minTileHeight: 72,
        leading: const Icon(
          Icons.error_outline_rounded,
          color: AppColors.negative,
        ),
        title: Text(
          context.l10n.text('updateFailed'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(status.error ?? context.l10n.text('updateRetryHint')),
      );
    }

    final percent = status.progress == null
        ? null
        : (status.progress! * 100).round();
    final downloading = context.l10n.text('downloadingUpdate', {
      'version': status.version ?? '',
    });
    return ListTile(
      minTileHeight: 94,
      leading: const Icon(Icons.downloading_rounded),
      title: Text(
        '$downloading${percent == null ? '' : ' - $percent%'}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: status.progress),
            const SizedBox(height: 6),
            Text(context.l10n.text('downloadContinues')),
          ],
        ),
      ),
    );
  }
}

class DailyUpdateCheck extends ConsumerStatefulWidget {
  const DailyUpdateCheck({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DailyUpdateCheck> createState() => _DailyUpdateCheckState();
}

class _DailyUpdateCheckState extends ConsumerState<DailyUpdateCheck>
    with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted || _checking) return;
    _checking = true;
    try {
      await ref.read(updateServiceProvider).refreshDownloadStatus();
      if (mounted) {
        await checkAndOfferUpdate(context, ref, manual: false);
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

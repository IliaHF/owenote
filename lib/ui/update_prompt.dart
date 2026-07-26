import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      if (manual) showMessage(context, 'OweNote is up to date.');
      return;
    }

    final install = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded),
        title: Text('OweNote ${update.version} is available'),
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
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update now'),
          ),
        ],
      ),
    );
    if (install != true || !context.mounted) return;

    final status = await service.startUpdate(update);
    if (context.mounted && status.phase == UpdateDownloadPhase.downloading) {
      showMessage(
        context,
        'Downloading OweNote ${update.version} in the background.',
      );
    }
  } catch (error) {
    if (manual && context.mounted) {
      showMessage(context, friendlyError(error));
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
          const Text('A new version of OweNote is ready to install.')
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
          label: const Text('Full changelog'),
        ),
      ],
    );
  }
}

class UpdateDownloadBanner extends ConsumerWidget {
  const UpdateDownloadBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(updateDownloadStatusProvider).value ??
        UpdateDownloadStatus.idle;
    return Stack(
      children: [
        child,
        if (status.phase != UpdateDownloadPhase.idle)
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: _DownloadStatusContent(status: status),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DownloadStatusContent extends ConsumerWidget {
  const _DownloadStatusContent({required this.status});

  final UpdateDownloadStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status.phase == UpdateDownloadPhase.ready) {
      return Row(
        children: [
          const Icon(Icons.download_done_rounded, color: AppColors.positive),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'OweNote ${status.version ?? ''} is ready to install.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: () =>
                ref.read(updateServiceProvider).installDownloadedUpdate(),
            child: const Text('Install'),
          ),
        ],
      );
    }

    if (status.phase == UpdateDownloadPhase.failed) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.negative),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.error ?? 'The update download failed. Try again.',
            ),
          ),
        ],
      );
    }

    final percent = status.progress == null
        ? null
        : (status.progress! * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.downloading_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Downloading OweNote ${status.version ?? ''}'
                '${percent == null ? '' : ' — $percent%'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: status.progress),
        const SizedBox(height: 4),
        const Text(
          'You can keep using OweNote. Progress is also in notifications.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
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

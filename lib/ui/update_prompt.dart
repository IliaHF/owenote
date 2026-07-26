import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
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
        content: Text(
          update.releaseNotes.isEmpty
              ? 'Download and install the latest version now?'
              : '${update.releaseNotes}\n\nDownload and install now?',
          maxLines: 12,
          overflow: TextOverflow.fade,
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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Downloading update...')),
          ],
        ),
      ),
    );
    try {
      await service.downloadAndInstall(update);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      rethrow;
    }
  } catch (error) {
    if (manual && context.mounted) {
      showMessage(context, friendlyError(error));
    }
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
      await checkAndOfferUpdate(context, ref, manual: false);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../core/icons.dart';
import '../core/money.dart';
import '../core/preferences.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import 'choice_sheet.dart';
import 'update_prompt.dart';
import 'widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool busy = false;

  Future<void> run(Future<String> Function() operation) async {
    setState(() => busy = true);
    try {
      final message = await operation();
      if (mounted) showMessage(context, message);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null) return;
    setState(() => busy = true);
    try {
      final file = picked.files.single;
      final source = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
      final service = ref.read(backupServiceProvider);
      final preview = service.validate(source);
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(PhosphorIconsRegular.fileArrowDown),
          title: const Text('Import backup?'),
          content: Text(
            'Exported ${DateFormat.yMMMd().add_jm().format(preview.exportedAt.toLocal())}\n\n'
            '${preview.peopleCount} people / ${preview.transactionCount} transactions\n\n'
            'This will replace all current OweNote data. It cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.negative,
              ),
              child: const Text('Replace all data'),
            ),
          ],
        ),
      );
      if (replace == true) {
        await service.replaceWith(preview);
        if (mounted) showMessage(context, 'Backup imported successfully.');
      }
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleBiometric(bool enabled) async {
    try {
      if (enabled) {
        final authentication = LocalAuthentication();
        if (!await authentication.isDeviceSupported() ||
            !await authentication.canCheckBiometrics) {
          throw const FormatException(
            'Biometric authentication is not available on this device.',
          );
        }
        final allowed = await authentication.authenticate(
          localizedReason: 'Enable biometric lock for OweNote',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (!allowed) return;
      }
      await ref.read(repositoryProvider).setBiometricEnabled(enabled);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error));
    }
  }

  Future<void> chooseCurrency(CurrencyOption current) async {
    final selected = await showModalBottomSheet<CurrencyOption>(
      context: context,
      builder: (context) => ChoiceSheet<CurrencyOption>(
        title: 'Currency',
        subtitle:
            'Amounts are relabelled only. Their values are not converted.',
        values: CurrencyOption.values,
        selected: current,
        label: (value) => value.code,
      ),
    );
    if (selected != null) {
      await ref.read(repositoryProvider).setCurrency(selected);
    }
  }

  Future<void> chooseWeekStart(WeekStartOption current) async {
    final selected = await showModalBottomSheet<WeekStartOption>(
      context: context,
      builder: (context) => ChoiceSheet<WeekStartOption>(
        title: 'Start of the week',
        subtitle: 'Used by OweNote date pickers.',
        values: WeekStartOption.values,
        selected: current,
        label: (value) => value.label,
      ),
    );
    if (selected != null) {
      await ref.read(repositoryProvider).setWeekStart(selected.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometric = ref.watch(biometricEnabledProvider).value ?? false;
    final currency = ref.watch(currencyProvider).value ?? CurrencyOption.chf;
    final weekStart =
        ref.watch(weekStartProvider).value ?? WeekStartOption.system;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const PageStorageKey('settings-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 22),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          _Section(
            title: 'Backup',
            children: [
              _SettingTile(
                icon: PhosphorIconsRegular.export,
                title: 'Export backup',
                subtitle: 'Save a JSON copy on this device',
                onTap: busy
                    ? null
                    : () => run(() async {
                        final file = await ref
                            .read(backupServiceProvider)
                            .saveBackup();
                        return 'Backup saved to ${file.path}';
                      }),
              ),
              _SettingTile(
                icon: PhosphorIconsRegular.fileArrowDown,
                title: 'Import backup',
                subtitle: 'Validate and replace current data',
                onTap: busy ? null : importBackup,
              ),
              _SettingTile(
                icon: PhosphorIconsRegular.shareNetwork,
                title: 'Share backup',
                subtitle: 'Open the native share sheet',
                onTap: busy
                    ? null
                    : () => run(() async {
                        await ref.read(backupServiceProvider).shareBackup();
                        return 'Backup ready to share.';
                      }),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Preferences',
            children: [
              _SettingTile(
                icon: PhosphorIconsRegular.currencyCircleDollar,
                title: 'Currency',
                subtitle: 'Relabel amounts without converting their values',
                value: currency.code,
                onTap: () => chooseCurrency(currency),
              ),
              _SettingTile(
                icon: PhosphorIconsRegular.calendarBlank,
                title: 'Start of the week',
                subtitle: 'Choose how date pickers are arranged',
                value: weekStart.label,
                onTap: () => chooseWeekStart(weekStart),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Privacy',
            children: [
              ListTile(
                minTileHeight: 72,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(PhosphorIconsRegular.fingerprint),
                title: const Text(
                  'Biometric lock',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Require biometrics when opening OweNote'),
                trailing: Switch(
                  value: biometric,
                  onChanged: toggleBiometric,
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.positive
                        : const Color(0xFFCDCDC7),
                  ),
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Your data stays on this device unless you export or share a backup.',
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'About',
            children: [
              const _InfoTile(label: 'Storage', value: 'On this device'),
              FutureBuilder<String>(
                future: ref.read(updateServiceProvider).currentVersion(),
                builder: (context, snapshot) => _InfoTile(
                  label: 'App version',
                  value: snapshot.data ?? '...',
                ),
              ),
              _SettingTile(
                icon: Icons.system_update_alt_rounded,
                title: 'Check for updates',
                subtitle: 'Get the latest release from GitHub',
                onTap: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        await checkAndOfferUpdate(context, ref, manual: true);
                        if (mounted) setState(() => busy = false);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Card(child: Column(children: children)),
    ],
  );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.value,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? value;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 68,
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(value!, style: const TextStyle(color: AppColors.muted)),
        if (value != null) const SizedBox(width: 6),
        const Icon(PhosphorIconsRegular.caretRight, size: 18),
      ],
    ),
    onTap: onTap,
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 54,
    title: Text(label),
    trailing: Text(
      value,
      style: const TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

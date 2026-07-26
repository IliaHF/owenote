import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../core/icons.dart';
import '../core/localization.dart';
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
      if (mounted) showMessage(context, friendlyError(context, error));
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
          title: Text(context.l10n.text('importBackupQuestion')),
          content: Text(
            context.l10n.text('importBackupSummary', {
              'date': DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).add_jm().format(preview.exportedAt.toLocal()),
              'people': preview.peopleCount,
              'transactions': preview.transactionCount,
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.text('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.negative,
              ),
              child: Text(context.l10n.text('replaceAllData')),
            ),
          ],
        ),
      );
      if (replace == true) {
        await service.replaceWith(preview);
        if (mounted) {
          showMessage(context, context.l10n.text('backupImported'));
        }
      }
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(context, error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleBiometric(bool enabled) async {
    final l10n = context.l10n;
    try {
      if (enabled) {
        final authentication = LocalAuthentication();
        if (!await authentication.isDeviceSupported() ||
            !await authentication.canCheckBiometrics) {
          throw FormatException(l10n.text('biometricUnavailable'));
        }
        final allowed = await authentication.authenticate(
          localizedReason: l10n.text('enableBiometricReason'),
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (!allowed) return;
      }
      await ref.read(repositoryProvider).setBiometricEnabled(enabled);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(context, error));
    }
  }

  Future<void> editCurrency(String current) async {
    final controller = TextEditingController(text: current);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.text('currency')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.text('currencyDialogSubtitle')),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 16,
              decoration: InputDecoration(
                labelText: context.l10n.text('currency'),
                hintText: context.l10n.text('currencyHint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.text('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(context.l10n.text('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (selected != null) {
      await ref.read(repositoryProvider).setCurrency(selected);
    }
  }

  Future<void> chooseLanguage(AppLanguage current) async {
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      builder: (context) => ChoiceSheet<AppLanguage>(
        title: context.l10n.text('language'),
        subtitle: context.l10n.text('languageSheetSubtitle'),
        values: AppLanguage.values,
        selected: current,
        label: (value) => context.l10n.text(
          value == AppLanguage.system ? 'systemDefault' : value.name,
        ),
      ),
    );
    if (selected != null) {
      await ref.read(repositoryProvider).setLanguage(selected.code ?? 'system');
    }
  }

  Future<void> chooseWeekStart(WeekStartOption current) async {
    final selected = await showModalBottomSheet<WeekStartOption>(
      context: context,
      builder: (context) => ChoiceSheet<WeekStartOption>(
        title: context.l10n.text('startOfWeek'),
        subtitle: context.l10n.text('startOfWeekSheetSubtitle'),
        values: WeekStartOption.values,
        selected: current,
        label: (value) => context.l10n.text(
          value == WeekStartOption.system ? 'systemDefault' : value.name,
        ),
      ),
    );
    if (selected != null) {
      await ref.read(repositoryProvider).setWeekStart(selected.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final biometric = ref.watch(biometricEnabledProvider).value ?? false;
    final currency = ref.watch(currencyProvider).value ?? 'CHF';
    final language = ref.watch(languageProvider).value ?? AppLanguage.system;
    final weekStart =
        ref.watch(weekStartProvider).value ?? WeekStartOption.system;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const PageStorageKey('settings-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Text(
            context.l10n.text('settings'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 22),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          _Section(
            title: context.l10n.text('backup'),
            children: [
              _SettingTile(
                icon: PhosphorIconsRegular.export,
                title: context.l10n.text('exportBackup'),
                subtitle: context.l10n.text('exportBackupSubtitle'),
                onTap: busy
                    ? null
                    : () => run(() async {
                        final destination = await ref
                            .read(backupServiceProvider)
                            .saveBackup();
                        return l10n.text('backupSaved', {'path': destination});
                      }),
              ),
              _SettingTile(
                icon: PhosphorIconsRegular.fileArrowDown,
                title: context.l10n.text('importBackup'),
                subtitle: context.l10n.text('importBackupSubtitle'),
                onTap: busy ? null : importBackup,
              ),
              _SettingTile(
                icon: PhosphorIconsRegular.shareNetwork,
                title: context.l10n.text('shareBackup'),
                subtitle: context.l10n.text('shareBackupSubtitle'),
                onTap: busy
                    ? null
                    : () => run(() async {
                        await ref.read(backupServiceProvider).shareBackup();
                        return l10n.text('backupReadyToShare');
                      }),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: context.l10n.text('preferences'),
            children: [
              _SettingTile(
                icon: PhosphorIconsRegular.currencyCircleDollar,
                title: context.l10n.text('currency'),
                subtitle: context.l10n.text('currencySubtitle'),
                value: currency,
                onTap: () => editCurrency(currency),
              ),
              _SettingTile(
                icon: PhosphorIconsRegular.translate,
                title: context.l10n.text('language'),
                subtitle: context.l10n.text('languageSubtitle'),
                value: context.l10n.text(
                  language == AppLanguage.system
                      ? 'systemDefault'
                      : language.name,
                ),
                onTap: () => chooseLanguage(language),
              ),
              _SettingTile(
                icon: PhosphorIconsRegular.calendarBlank,
                title: context.l10n.text('startOfWeek'),
                subtitle: context.l10n.text('startOfWeekSubtitle'),
                value: context.l10n.text(
                  weekStart == WeekStartOption.system
                      ? 'systemDefault'
                      : weekStart.name,
                ),
                onTap: () => chooseWeekStart(weekStart),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: context.l10n.text('privacy'),
            children: [
              ListTile(
                minTileHeight: 72,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(PhosphorIconsRegular.fingerprint),
                title: Text(
                  context.l10n.text('biometricLock'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(context.l10n.text('biometricLockSubtitle')),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  context.l10n.text('localDataNotice'),
                  style: const TextStyle(
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
            title: context.l10n.text('about'),
            children: [
              _InfoTile(
                label: context.l10n.text('storage'),
                value: context.l10n.text('onThisDevice'),
              ),
              FutureBuilder<String>(
                future: ref.read(updateServiceProvider).currentVersion(),
                builder: (context, snapshot) => _InfoTile(
                  label: context.l10n.text('appVersion'),
                  value: snapshot.data ?? '...',
                ),
              ),
              const UpdateDownloadStatusTile(),
              _SettingTile(
                icon: Icons.system_update_alt_rounded,
                title: context.l10n.text('checkForUpdates'),
                subtitle: context.l10n.text('checkForUpdatesSubtitle'),
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

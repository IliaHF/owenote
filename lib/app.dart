import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:owenote/core/icons.dart';
import 'package:owenote/core/money.dart';
import 'package:owenote/core/localization.dart';

import 'providers.dart';
import 'theme/app_theme.dart';
import 'ui/forms.dart';
import 'ui/history_screen.dart';
import 'ui/people_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/update_prompt.dart';

class OweNoteApp extends ConsumerWidget {
  const OweNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider).value ?? AppLanguage.system;
    Money.currency = ref.watch(currencyProvider).value ?? 'CHF';
    return MaterialApp(
      title: 'OweNote',
      debugShowCheckedModeBanner: false,
      locale: language.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: AppColors.background,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: child!,
      ),
      home: const BiometricGate(child: DailyUpdateCheck(child: AppShell())),
    );
  }
}

class _FastPageScrollPhysics extends PageScrollPhysics {
  const _FastPageScrollPhysics({super.parent});

  @override
  _FastPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _FastPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 1, stiffness: 700, damping: 53);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  late final PageController pageController = PageController();
  static const pages = [PeopleScreen(), HistoryScreen(), SettingsScreen()];

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void selectPage(int value) {
    if (value == index) return;
    setState(() => index = value);
    pageController.animateToPage(
      value,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: PageView(
      controller: pageController,
      physics: const _FastPageScrollPhysics(),
      onPageChanged: (value) {
        if (index != value) setState(() => index = value);
      },
      children: pages,
    ),
    floatingActionButton: AnimatedScale(
      scale: index == 0 ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: FloatingActionButton(
        tooltip: context.l10n.text('addPerson'),
        onPressed: index == 0 ? () => openPersonForm(context) : null,
        child: const Icon(PhosphorIconsRegular.plus),
      ),
    ),
    bottomNavigationBar: _PillNavigation(
      selectedIndex: index,
      onSelected: selectPage,
    ),
  );
}

class _PillNavigation extends StatelessWidget {
  const _PillNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const destinations = [
    (PhosphorIconsRegular.users, 'people'),
    (PhosphorIconsRegular.clockCounterClockwise, 'history'),
    (PhosphorIconsRegular.gearSix, 'settings'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 66,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / destinations.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * itemWidth + 7,
                  top: 7,
                  bottom: 7,
                  width: itemWidth - 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(destinations.length, (index) {
                    final destination = destinations[index];
                    final selected = selectedIndex == index;
                    final color = selected ? Colors.white : AppColors.muted;
                    return Expanded(
                      child: Semantics(
                        selected: selected,
                        button: true,
                        label: context.l10n.text(destination.$2),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: InkWell(
                            onTap: () => onSelected(index),
                            borderRadius: BorderRadius.circular(18),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedScale(
                                  scale: selected ? 1 : 0.92,
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  child: TweenAnimationBuilder<Color?>(
                                    tween: ColorTween(end: color),
                                    duration: const Duration(milliseconds: 240),
                                    builder: (context, value, child) => Icon(
                                      destination.$1,
                                      size: 21,
                                      color: value,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                  child: Text(
                                    context.l10n.text(destination.$2),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate>
    with WidgetsBindingObserver {
  bool authenticated = false;
  bool authenticating = false;
  bool attemptedAutomatically = false;
  String? authenticationError;
  DateTime? inactiveAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      inactiveAt ??= DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      final elapsed = inactiveAt == null
          ? Duration.zero
          : DateTime.now().difference(inactiveAt!);
      inactiveAt = null;
      if (elapsed > const Duration(seconds: 30) && mounted) {
        setState(() {
          authenticated = false;
          attemptedAutomatically = false;
          authenticationError = null;
        });
      }
    }
  }

  Future<void> authenticate() async {
    if (authenticating) return;
    setState(() {
      authenticating = true;
      attemptedAutomatically = true;
      authenticationError = null;
    });
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) {
        if (mounted) {
          setState(() {
            authenticated = false;
            authenticationError = context.l10n.text('biometricUnavailable');
          });
        }
        return;
      }
      final ok = await auth.authenticate(
        localizedReason: 'Unlock OweNote',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (mounted) {
        setState(() {
          authenticated = ok;
          if (!ok) {
            authenticationError = context.l10n.text('biometricCancelled');
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          authenticated = false;
          authenticationError = context.l10n.text('authenticationFailed');
        });
      }
    } finally {
      if (mounted) setState(() => authenticating = false);
    }
  }

  Widget lockedScreen(BuildContext context, {required String message}) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(PhosphorIconsRegular.fingerprint, size: 56),
                const SizedBox(height: 18),
                Text(
                  context.l10n.text('appLocked'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: authenticating ? null : authenticate,
                  icon: const Icon(PhosphorIconsRegular.lockKeyOpen),
                  label: Text(
                    context.l10n.text(
                      authenticating ? 'authenticating' : 'retry',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricEnabledProvider);
    return enabled.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => lockedScreen(
        context,
        message: context.l10n.text('biometricSettingError'),
      ),
      data: (isEnabled) {
        if (!isEnabled || authenticated) return widget.child;
        if (!attemptedAutomatically && !authenticating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !attemptedAutomatically && !authenticated) {
              authenticate();
            }
          });
        }
        return lockedScreen(
          context,
          message:
              authenticationError ?? context.l10n.text('authenticateLedger'),
        );
      },
    );
  }
}

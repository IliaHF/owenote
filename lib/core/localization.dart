import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppLanguage {
  system(null),
  english('en'),
  german('de'),
  french('fr'),
  italian('it'),
  spanish('es'),
  ukrainian('uk'),
  albanian('sq'),
  brazilianPortuguese('pt', 'BR');

  const AppLanguage(this.code, [this.countryCode]);
  final String? code;
  final String? countryCode;

  Locale? get locale => code == null ? null : Locale(code!, countryCode);

  static AppLanguage fromPreference(String value) => values.firstWhere(
    (language) => language.code == value,
    orElse: () => AppLanguage.system,
  );
}

class AppLocalizations {
  AppLocalizations(this.locale, this._values);

  final Locale locale;
  final Map<String, String> _values;

  static const supportedLocales = [
    Locale('en'),
    Locale('de'),
    Locale('fr'),
    Locale('it'),
    Locale('es'),
    Locale('uk'),
    Locale('sq'),
    Locale('pt', 'BR'),
  ];

  static const delegate = _AppLocalizationsDelegate();

  static final _fallback = AppLocalizations(const Locale('en'), const {
    'owesYouAmount': 'Owes you {amount}',
    'youOweAmount': 'You owe {amount}',
    'settled': 'Settled',
  });

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      _fallback;

  String text(String key, [Map<String, Object> arguments = const {}]) {
    var value = _values[key] ?? key;
    for (final entry in arguments.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final english = await _loadMap('en');
    if (locale.languageCode == 'en') {
      return AppLocalizations(locale, english);
    }
    final translated = await _loadMap(locale.languageCode);
    return AppLocalizations(locale, {...english, ...translated});
  }

  Future<Map<String, String>> _loadMap(String code) async {
    final source = await rootBundle.loadString('assets/l10n/$code.json');
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

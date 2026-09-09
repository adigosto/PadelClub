import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'bosnian_messages.dart';

/// Message IDs are the English source text. Only UI messages are translated;
/// API values, identifiers and user-authored content retain their original form.
class AppLocalizations {
  const AppLocalizations(this.locale, this.messages);

  final Locale locale;
  final Map<String, String> messages;

  static const supportedLocales = [Locale('en'), Locale('bs')];
  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'), {});

  String text(String message, [Map<String, Object?> values = const {}]) {
    final translated = messages[message] ?? message;
    return translated.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final name = match.group(1)!;
      return values.containsKey(name)
          ? '${values[name] ?? ''}'
          : match.group(0)!;
    });
  }

  static bool _dateDataReady = false;

  String date(DateTime value) {
    if (!_dateDataReady) {
      // The local-data initializer registers its bundled tables synchronously.
      initializeDateFormatting();
      _dateDataReady = true;
    }
    return DateFormat.yMMMd(locale.languageCode).format(value.toLocal());
  }

  String number(num value, {int? decimalDigits}) {
    final format = NumberFormat.decimalPattern(locale.languageCode);
    if (decimalDigits != null) {
      format.minimumFractionDigits = decimalDigits;
      format.maximumFractionDigits = decimalDigits;
    }
    return format.format(value);
  }

  String money(num value) => '${number(value, decimalDigits: 2)} KM';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(
    AppLocalizations(
      locale,
      locale.languageCode == 'bs' ? bosnianMessages : const {},
    ),
  );

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String message, [Map<String, Object?> values = const {}]) =>
      l10n.text(message, values);
}

import 'package:padelclub_desktop/core/localization/app_localizations.dart';

abstract final class FormValidators {
  // Text fields accept Unicode, including č, ć, đ, š and ž. Only length and
  // field-specific rules are checked; names and addresses are not ASCII-only.
  static String? text(
    String? value, {
    required String label,
    int minLength = 1,
    int? maxLength,
    bool optional = false,
    AppLocalizations? l10n,
  }) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return optional
          ? null
          : l10n?.text('Enter {label}.', {'label': l10n.text(label)}) ??
                'Enter $label.';
    }
    if (input.length < minLength) {
      return l10n?.text('{label} must contain at least {count} characters.', {
            'label': l10n.text(label),
            'count': minLength,
          }) ??
          '$label must contain at least $minLength characters.';
    }
    if (maxLength != null && input.length > maxLength) {
      return l10n?.text(
            '{label} must contain no more than {count} characters.',
            {'label': l10n.text(label), 'count': maxLength},
          ) ??
          '$label must contain no more than $maxLength characters.';
    }
    return null;
  }

  static String? email(String? value, {AppLocalizations? l10n}) {
    final required = text(
      value,
      label: 'your email',
      maxLength: 255,
      l10n: l10n,
    );
    if (required != null) return required;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
        ? null
        : l10n?.text('Enter an email such as name@example.com.') ??
              'Enter an email such as name@example.com.';
  }

  static String? phone(
    String? value, {
    bool optional = false,
    AppLocalizations? l10n,
  }) {
    final required = text(
      value,
      label: 'a phone number',
      maxLength: 30,
      optional: optional,
      l10n: l10n,
    );
    if (required != null || (optional && (value?.trim().isEmpty ?? true))) {
      return required;
    }
    final input = value!.trim();
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^\+?[0-9\s()./-]+$').hasMatch(input) ||
        digits.length < 6 ||
        digits.length > 15) {
      return l10n?.text('Enter 6–15 digits, for example +387 61 123 456.') ??
          'Enter 6–15 digits, for example +387 61 123 456.';
    }
    return null;
  }

  static double? decimalValue(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  static String? decimal(
    String? value, {
    required String label,
    double minimum = 0,
    AppLocalizations? l10n,
  }) {
    if (value?.trim().isEmpty ?? true) {
      return l10n?.text('Enter {label}.', {'label': l10n.text(label)}) ??
          'Enter $label.';
    }
    final number = decimalValue(value);
    if (number == null || !number.isFinite) {
      return l10n?.text('Enter a valid number.') ?? 'Enter a valid number.';
    }
    if (number < minimum) {
      return l10n?.text('Enter {minimum} or more.', {
            'minimum': l10n.number(minimum),
          }) ??
          'Enter $minimum or more.';
    }
    return null;
  }

  static String? integer(
    String? value, {
    required String label,
    int minimum = 1,
    int? maximum,
    AppLocalizations? l10n,
  }) {
    if (value?.trim().isEmpty ?? true) {
      return l10n?.text('Enter {label}.', {'label': l10n.text(label)}) ??
          'Enter $label.';
    }
    final number = int.tryParse(value!.trim());
    if (number == null) {
      return l10n?.text('Enter a whole number.') ?? 'Enter a whole number.';
    }
    if (number < minimum || (maximum != null && number > maximum)) {
      return maximum == null
          ? l10n?.text('Enter {minimum} or more.', {'minimum': minimum}) ??
                'Enter $minimum or more.'
          : l10n?.text('Enter a number from {minimum} to {maximum}.', {
                  'minimum': minimum,
                  'maximum': maximum,
                }) ??
                'Enter a number from $minimum to $maximum.';
    }
    return null;
  }
}

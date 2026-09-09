import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class LocaleStore {
  Future<String?> read();
  Future<void> write(String languageCode);
}

class DeviceLocaleStore implements LocaleStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'padelclub_language';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String languageCode) =>
      _storage.write(key: _key, value: languageCode);
}

class LocaleController extends ChangeNotifier {
  LocaleController({LocaleStore? store})
    : _store = store ?? DeviceLocaleStore();

  final LocaleStore _store;
  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  bool _changed = false;
  bool _disposed = false;
  Future<void> _pendingWrite = Future.value();

  Future<void> load() async {
    try {
      final saved = await _store.read();
      if (_disposed || _changed || !['en', 'bs'].contains(saved)) return;
      _locale = Locale(saved!);
      notifyListeners();
    } catch (_) {
      // Device storage may be unavailable; English remains usable.
    }
  }

  Future<bool> setLanguage(String code) async {
    if (!['en', 'bs'].contains(code)) throw ArgumentError.value(code);
    _changed = true;
    _locale = Locale(code);
    notifyListeners();
    var saved = true;
    // Serialize writes so rapid switching persists the last selection.
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _store.write(code);
      } catch (_) {
        saved = false;
      }
    });
    await _pendingWrite;
    return saved;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class LanguageScope extends InheritedNotifier<LocaleController> {
  const LanguageScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier;
}

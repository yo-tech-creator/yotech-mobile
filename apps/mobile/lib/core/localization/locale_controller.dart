import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/providers/shared_preferences_provider.dart';

const supportedAppLocales = <Locale>[
  Locale('tr'),
  Locale('en'),
];

class LocaleController extends Notifier<Locale> {
  static const _storageKey = 'app_locale';

  @override
  Locale build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_storageKey);
    if (stored != null && _isSupported(stored)) {
      return Locale(stored);
    }

    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    if (deviceLocale.languageCode.isNotEmpty &&
        _isSupported(deviceLocale.languageCode)) {
      return Locale(deviceLocale.languageCode);
    }

    return const Locale('tr');
  }

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode)) {
      return;
    }
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_storageKey, locale.languageCode);
  }

  bool _isSupported(String code) {
    return supportedAppLocales
        .any((locale) => locale.languageCode == code.toLowerCase());
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(() => LocaleController());

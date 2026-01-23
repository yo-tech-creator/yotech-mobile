import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/providers/shared_preferences_provider.dart';
import 'package:yotech_mobile/core/theme/app_theme.dart';

class AppThemeController extends Notifier<AppTheme> {
  static const _storageKey = 'app_theme';

  @override
  AppTheme build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_storageKey);
    if (stored == AppTheme.vibrant.name) return AppTheme.vibrant;
    if (stored == AppTheme.minimal.name) return AppTheme.minimal;
    return AppTheme.minimal;
  }

  Future<void> setTheme(AppTheme theme) async {
    state = theme;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_storageKey, theme.name);
  }
}

final appThemeControllerProvider =
    NotifierProvider<AppThemeController, AppTheme>(() => AppThemeController());

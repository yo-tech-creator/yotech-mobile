import 'package:flutter/widgets.dart';
import 'package:yotech_mobile/l10n/app_localizations.dart';

extension LocalizationX on BuildContext {
  AppLocalizations get l10n {
    final localizations = AppLocalizations.of(this);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }
}

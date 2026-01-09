// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Yotech';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get tryAgain => 'Try Again';

  @override
  String get settingsDefaultDisplayName => 'YOTECH User';

  @override
  String get settingsDefaultRole => 'Store Team Member';

  @override
  String get settingsTitle => 'My Account';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionOther => 'Other';

  @override
  String get settingsPersonalInfoTitle => 'Personal Information';

  @override
  String get settingsPersonalInfoSubtitle =>
      'View name, contact, and login details';

  @override
  String get settingsTeamTitle => 'My Team';

  @override
  String get settingsTeamSubtitle =>
      'Store teammates and regional manager info';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String settingsLanguageSubtitle(String language) {
    return 'App language: $language';
  }

  @override
  String get settingsNotificationsTitle => 'Notification Settings';

  @override
  String get settingsNotificationsSubtitle =>
      'Manage SKT, warehouse transfer, announcement, and task alerts';

  @override
  String get settingsContractsTitle => 'Contracts';

  @override
  String get settingsContractsSubtitle => 'KVKK and employment agreements';

  @override
  String settingsVersionLabel(String version) {
    return 'App Version $version';
  }

  @override
  String get settingsLogoutButton => 'Sign Out';

  @override
  String get settingsLogoutSuccess => 'Signed out';

  @override
  String get settingsLanguageChanged => 'Language updated';

  @override
  String get languageNameTurkish => 'Turkish';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get settingsLanguageSheetTitle => 'Choose language';

  @override
  String get settingsLanguageSheetDescription =>
      'Select the language you want to use in the app';

  @override
  String get announcementsTitle => 'Announcements';

  @override
  String announcementsLoadError(String error) {
    return 'Announcements couldn\'t be loaded: $error';
  }

  @override
  String announcementsAuthor(String author) {
    return 'Prepared by $author';
  }

  @override
  String get announcementsEmptyMessage =>
      'No announcements yet. Keep notifications on so you don\'t miss updates!';

  @override
  String get relativeJustNow => 'Just now';

  @override
  String relativeMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String relativeHours(int hours) {
    return '$hours hr ago';
  }

  @override
  String relativeDays(int days) {
    return '$days day(s) ago';
  }

  @override
  String get loginErrorTitle => 'Login Failed';

  @override
  String get dialogOk => 'OK';

  @override
  String get loginHeading => 'Sign In';

  @override
  String get loginIdLabel => 'ID / Employee No';

  @override
  String get loginIdHint => 'Enter your employee number';

  @override
  String get loginIdEmpty => 'Employee number can\'t be empty';

  @override
  String get loginIdTooShort => 'Employee number must be at least 3 characters';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => 'Enter your password';

  @override
  String get loginPasswordEmpty => 'Password can\'t be empty';

  @override
  String get loginButton => 'Sign In';

  @override
  String loginVersionLabel(String version) {
    return '$version';
  }

  @override
  String get breaksTitle => 'Shifts & Breaks';

  @override
  String get breaksTodayTitle => 'Today\'s Breaks';

  @override
  String breaksHistoryError(String error) {
    return 'History couldn\'t be loaded: $error';
  }

  @override
  String get breaksHighlightsTitle => 'Shift Planning';

  @override
  String get breaksHighlightsDescription =>
      'Soon you\'ll drag and drop shift blocks and manage them with the leave calendar. For now you can start and stop breaks here.';

  @override
  String get breaksHighlightWeeklyTitle => 'Weekly Kanban';

  @override
  String get breaksHighlightWeeklyDescription =>
      'Move teammates across cards to adjust shift blocks instantly.';

  @override
  String get breaksHighlightLeaveTitle => 'Leave Integration';

  @override
  String get breaksHighlightLeaveDescription =>
      'Approved leaves automatically block the calendar and suggest candidates for open slots.';

  @override
  String get breaksHighlightNotificationTitle => 'Notified Changes';

  @override
  String get breaksHighlightNotificationDescription =>
      'Shift swap requests send push notifications to the relevant teammates.';

  @override
  String get breaksOngoing => 'In progress';

  @override
  String breaksDurationLabel(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get breaksEmptyMessage => 'No breaks recorded for today.';

  @override
  String get breakQuickTitle => 'My Break';

  @override
  String get breakQuickHistory => 'History';

  @override
  String breakQuickLoadError(String error) {
    return 'Break info couldn\'t be loaded: $error';
  }

  @override
  String get breakQuickIdle =>
      'You don\'t have an active break. Tap the button below to start one.';

  @override
  String get breakQuickStop => 'End Break';

  @override
  String get breakQuickStart => 'Start Break';

  @override
  String get breakQuickRefreshTooltip => 'Refresh status';

  @override
  String get breakQuickEndSuccess => 'Break ended.';

  @override
  String get breakQuickStartSuccess => 'Break started.';

  @override
  String breakQuickFailure(String error) {
    return 'Action failed: $error';
  }

  @override
  String breakQuickStartedAt(String time) {
    return 'Break started at $time.';
  }

  @override
  String breakQuickElapsed(String time) {
    return 'Elapsed: $time';
  }

  @override
  String commonActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDismiss => 'Cancel';

  @override
  String get merchSearchHint => 'Search company or name';

  @override
  String get merchTitle => 'Merch / Field Rep';

  @override
  String get merchSearchClose => 'Close search';

  @override
  String get merchSearchToggle => 'Filter / Search';

  @override
  String get merchAddPerson => 'Add Person';

  @override
  String merchLoadError(String error) {
    return 'Merch list couldn\'t be loaded: $error';
  }

  @override
  String get merchEditTitle => 'Edit Person';

  @override
  String get merchCreateTitle => 'Add New Person';

  @override
  String get merchFieldFirstName => 'First name';

  @override
  String get merchFieldLastName => 'Last name';

  @override
  String get merchFieldCompany => 'Company name';

  @override
  String get merchFieldPhone => 'Phone number';

  @override
  String get merchPhoneRequired => 'Phone is required';

  @override
  String get merchPhoneInvalid => 'Enter a valid phone number';

  @override
  String get merchFieldRank => 'Rank';

  @override
  String get merchUpdateButton => 'Update Person';

  @override
  String get merchAddButton => 'Add Person';

  @override
  String merchFieldRequired(String field) {
    return '$field is required';
  }

  @override
  String get merchUpdateSuccess => 'Person updated';

  @override
  String get merchCreateSuccess => 'Person added';

  @override
  String get merchDeleteTitle => 'Delete person';

  @override
  String merchDeleteMessage(String name) {
    return 'Are you sure you want to delete $name?';
  }

  @override
  String get merchDeleteSuccess => 'Person deleted';

  @override
  String merchDeleteFailure(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get merchEmptyFiltered => 'No results match your search.';

  @override
  String get merchEmptyDefault =>
      'No entries yet. Use the button above to add teammates.';

  @override
  String get merchRankMerch => 'Merch';

  @override
  String get merchRankPlasiyer => 'Field Rep';

  @override
  String get merchRankSevkiyat => 'Logistics';

  @override
  String get merchRankSef => 'Lead';

  @override
  String get merchRankYonetici => 'Manager';
}

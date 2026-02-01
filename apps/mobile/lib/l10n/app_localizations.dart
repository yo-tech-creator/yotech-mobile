import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('tr'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yotech'**
  String get appTitle;

  /// Hata mesajını gösterir
  ///
  /// In tr, this message translates to:
  /// **'Hata: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @tryAgain.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get tryAgain;

  /// No description provided for @settingsDefaultDisplayName.
  ///
  /// In tr, this message translates to:
  /// **'YOTECH Kullanıcısı'**
  String get settingsDefaultDisplayName;

  /// No description provided for @settingsDefaultRole.
  ///
  /// In tr, this message translates to:
  /// **'Kasa Reyon Personeli'**
  String get settingsDefaultRole;

  /// No description provided for @settingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabım'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get settingsSectionOther;

  /// No description provided for @settingsPersonalInfoTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kişisel Bilgilerim'**
  String get settingsPersonalInfoTitle;

  /// No description provided for @settingsPersonalInfoSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Ad, iletişim ve giriş bilgilerini görüntüle'**
  String get settingsPersonalInfoSubtitle;

  /// No description provided for @settingsTeamTitle.
  ///
  /// In tr, this message translates to:
  /// **'Takım arkadaşlarım'**
  String get settingsTeamTitle;

  /// No description provided for @settingsTeamSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Şubendeki ekip ve bölge müdürü bilgileri'**
  String get settingsTeamSubtitle;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get settingsLanguageTitle;

  /// Dil seçeneği alt başlığı
  ///
  /// In tr, this message translates to:
  /// **'Uygulama dili: {language}'**
  String settingsLanguageSubtitle(String language);

  /// No description provided for @settingsNotificationsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim Ayarları'**
  String get settingsNotificationsTitle;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'SKT, depo sevk, duyuru ve görev bildirimlerini yönet'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsContractsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sözleşmeler'**
  String get settingsContractsTitle;

  /// No description provided for @settingsContractsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'KVKK ve çalışma sözleşmeleri'**
  String get settingsContractsSubtitle;

  /// Uygulama versiyon bilgisini gösterir
  ///
  /// In tr, this message translates to:
  /// **'Uygulama Versiyonu {version}'**
  String settingsVersionLabel(String version);

  /// No description provided for @settingsLogoutButton.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get settingsLogoutButton;

  /// No description provided for @settingsLogoutSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Oturum kapatıldı'**
  String get settingsLogoutSuccess;

  /// No description provided for @settingsLanguageChanged.
  ///
  /// In tr, this message translates to:
  /// **'Dil değiştirildi'**
  String get settingsLanguageChanged;

  /// No description provided for @languageNameTurkish.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get languageNameTurkish;

  /// No description provided for @languageNameEnglish.
  ///
  /// In tr, this message translates to:
  /// **'İngilizce'**
  String get languageNameEnglish;

  /// No description provided for @settingsLanguageSheetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Dil seçimi'**
  String get settingsLanguageSheetTitle;

  /// No description provided for @settingsLanguageSheetDescription.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama için kullanmak istediğiniz dili seçin'**
  String get settingsLanguageSheetDescription;

  /// No description provided for @announcementsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get announcementsTitle;

  /// Duyuru sayfası hata mesajı
  ///
  /// In tr, this message translates to:
  /// **'Duyurular yüklenemedi: {error}'**
  String announcementsLoadError(String error);

  /// Duyuruyu hazırlayan kişi
  ///
  /// In tr, this message translates to:
  /// **'Hazırlayan: {author}'**
  String announcementsAuthor(String author);

  /// No description provided for @announcementsEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Henüz duyuru yayınlanmamış. Yenilikleri kaçırmamak için bildirimlerini açık tut!'**
  String get announcementsEmptyMessage;

  /// No description provided for @relativeJustNow.
  ///
  /// In tr, this message translates to:
  /// **'Az önce'**
  String get relativeJustNow;

  /// No description provided for @relativeMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk önce'**
  String relativeMinutes(int minutes);

  /// No description provided for @relativeHours.
  ///
  /// In tr, this message translates to:
  /// **'{hours} sa önce'**
  String relativeHours(int hours);

  /// No description provided for @relativeDays.
  ///
  /// In tr, this message translates to:
  /// **'{days} gün önce'**
  String relativeDays(int days);

  /// No description provided for @loginErrorTitle.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Başarısız'**
  String get loginErrorTitle;

  /// No description provided for @dialogOk.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get dialogOk;

  /// No description provided for @loginHeading.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get loginHeading;

  /// No description provided for @loginIdLabel.
  ///
  /// In tr, this message translates to:
  /// **'ID / Sicil No'**
  String get loginIdLabel;

  /// No description provided for @loginIdHint.
  ///
  /// In tr, this message translates to:
  /// **'Sicil numaranızı girin'**
  String get loginIdHint;

  /// No description provided for @loginIdEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Sicil no boş olamaz'**
  String get loginIdEmpty;

  /// No description provided for @loginIdTooShort.
  ///
  /// In tr, this message translates to:
  /// **'Sicil no en az 3 karakter olmalı'**
  String get loginIdTooShort;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In tr, this message translates to:
  /// **'Şifrenizi girin'**
  String get loginPasswordHint;

  /// No description provided for @loginPasswordEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Şifre boş olamaz'**
  String get loginPasswordEmpty;

  /// No description provided for @loginButton.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get loginButton;

  /// No description provided for @loginVersionLabel.
  ///
  /// In tr, this message translates to:
  /// **'{version}'**
  String loginVersionLabel(String version);

  /// No description provided for @breaksTitle.
  ///
  /// In tr, this message translates to:
  /// **'Vardiya ve Molalar'**
  String get breaksTitle;

  /// No description provided for @breaksTodayTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bugünkü Molalar'**
  String get breaksTodayTitle;

  /// No description provided for @breaksHistoryError.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş yüklenemedi: {error}'**
  String breaksHistoryError(String error);

  /// No description provided for @breaksHighlightsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Vardiya Planlama'**
  String get breaksHighlightsTitle;

  /// No description provided for @breaksHighlightsDescription.
  ///
  /// In tr, this message translates to:
  /// **'Yakında vardiya bloklarını sürükle-bırak düzenleyip izin takvimiyle entegre yöneteceksiniz. Şimdilik molalarınızı buradan açıp kapatabilirsiniz.'**
  String get breaksHighlightsDescription;

  /// No description provided for @breaksHighlightWeeklyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık Kanban'**
  String get breaksHighlightWeeklyTitle;

  /// No description provided for @breaksHighlightWeeklyDescription.
  ///
  /// In tr, this message translates to:
  /// **'Personeli kartlar üzerinde gezdirerek vardiya bloklarını anında ayarlayın.'**
  String get breaksHighlightWeeklyDescription;

  /// No description provided for @breaksHighlightLeaveTitle.
  ///
  /// In tr, this message translates to:
  /// **'İzin Entegrasyonu'**
  String get breaksHighlightLeaveTitle;

  /// No description provided for @breaksHighlightLeaveDescription.
  ///
  /// In tr, this message translates to:
  /// **'Onaylı izinler otomatik olarak takvimden düşer, boş slotlara aday önerilir.'**
  String get breaksHighlightLeaveDescription;

  /// No description provided for @breaksHighlightNotificationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimli Değişim'**
  String get breaksHighlightNotificationTitle;

  /// No description provided for @breaksHighlightNotificationDescription.
  ///
  /// In tr, this message translates to:
  /// **'Vardiya değiş tokuş talepleri push bildirimi ile ilgili kişilere düşer.'**
  String get breaksHighlightNotificationDescription;

  /// No description provided for @breaksOngoing.
  ///
  /// In tr, this message translates to:
  /// **'Devam ediyor'**
  String get breaksOngoing;

  /// No description provided for @breaksDurationLabel.
  ///
  /// In tr, this message translates to:
  /// **'Süre: {duration}'**
  String breaksDurationLabel(String duration);

  /// No description provided for @breaksEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bugün için kaydedilmiş mola bulunmuyor.'**
  String get breaksEmptyMessage;

  /// No description provided for @breakQuickTitle.
  ///
  /// In tr, this message translates to:
  /// **'Molam'**
  String get breakQuickTitle;

  /// No description provided for @breakQuickHistory.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get breakQuickHistory;

  /// No description provided for @breakQuickLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Mola bilgisi alınamadı: {error}'**
  String breakQuickLoadError(String error);

  /// No description provided for @breakQuickIdle.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda açık bir mola yok. Başlatmak için aşağıdaki düğmeye dokunun.'**
  String get breakQuickIdle;

  /// No description provided for @breakQuickStop.
  ///
  /// In tr, this message translates to:
  /// **'Molayı Bitir'**
  String get breakQuickStop;

  /// No description provided for @breakQuickStart.
  ///
  /// In tr, this message translates to:
  /// **'Molayı Başlat'**
  String get breakQuickStart;

  /// No description provided for @breakQuickRefreshTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Durumu yenile'**
  String get breakQuickRefreshTooltip;

  /// No description provided for @breakQuickEndSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Mola sonlandırıldı.'**
  String get breakQuickEndSuccess;

  /// No description provided for @breakQuickStartSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Mola başlatıldı.'**
  String get breakQuickStartSuccess;

  /// No description provided for @breakQuickFailure.
  ///
  /// In tr, this message translates to:
  /// **'İşlem başarısız: {error}'**
  String breakQuickFailure(String error);

  /// No description provided for @breakQuickStartedAt.
  ///
  /// In tr, this message translates to:
  /// **'Mola {time} saatinde başladı.'**
  String breakQuickStartedAt(String time);

  /// No description provided for @breakQuickElapsed.
  ///
  /// In tr, this message translates to:
  /// **'Geçen süre: {time}'**
  String breakQuickElapsed(String time);

  /// No description provided for @commonActionFailed.
  ///
  /// In tr, this message translates to:
  /// **'İşlem başarısız: {error}'**
  String commonActionFailed(String error);

  /// No description provided for @commonEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get commonEdit;

  /// No description provided for @commonDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get commonDelete;

  /// No description provided for @commonDismiss.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get commonDismiss;

  /// No description provided for @merchSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Firma veya isim ara'**
  String get merchSearchHint;

  /// No description provided for @merchTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mörş / Plasiyer'**
  String get merchTitle;

  /// No description provided for @merchSearchClose.
  ///
  /// In tr, this message translates to:
  /// **'Aramayı kapat'**
  String get merchSearchClose;

  /// No description provided for @merchSearchToggle.
  ///
  /// In tr, this message translates to:
  /// **'Filtre / Ara'**
  String get merchSearchToggle;

  /// No description provided for @merchAddPerson.
  ///
  /// In tr, this message translates to:
  /// **'Personel Ekle'**
  String get merchAddPerson;

  /// No description provided for @merchLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Mörş listesi yüklenemedi: {error}'**
  String merchLoadError(String error);

  /// No description provided for @merchEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Personeli Düzenle'**
  String get merchEditTitle;

  /// No description provided for @merchCreateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Personel Ekle'**
  String get merchCreateTitle;

  /// No description provided for @merchFieldFirstName.
  ///
  /// In tr, this message translates to:
  /// **'İsim'**
  String get merchFieldFirstName;

  /// No description provided for @merchFieldLastName.
  ///
  /// In tr, this message translates to:
  /// **'Soyisim'**
  String get merchFieldLastName;

  /// No description provided for @merchFieldCompany.
  ///
  /// In tr, this message translates to:
  /// **'Firma adı'**
  String get merchFieldCompany;

  /// No description provided for @merchFieldPhone.
  ///
  /// In tr, this message translates to:
  /// **'Telefon numarası'**
  String get merchFieldPhone;

  /// No description provided for @merchPhoneRequired.
  ///
  /// In tr, this message translates to:
  /// **'Telefon gerekli'**
  String get merchPhoneRequired;

  /// No description provided for @merchPhoneInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir numara girin'**
  String get merchPhoneInvalid;

  /// No description provided for @merchFieldRank.
  ///
  /// In tr, this message translates to:
  /// **'Rütbe'**
  String get merchFieldRank;

  /// No description provided for @merchUpdateButton.
  ///
  /// In tr, this message translates to:
  /// **'Personeli Güncelle'**
  String get merchUpdateButton;

  /// No description provided for @merchAddButton.
  ///
  /// In tr, this message translates to:
  /// **'Personel Ekle'**
  String get merchAddButton;

  /// No description provided for @merchFieldRequired.
  ///
  /// In tr, this message translates to:
  /// **'{field} gerekli'**
  String merchFieldRequired(String field);

  /// No description provided for @merchUpdateSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Personel güncellendi'**
  String get merchUpdateSuccess;

  /// No description provided for @merchCreateSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Personel eklendi'**
  String get merchCreateSuccess;

  /// No description provided for @merchDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Personeli sil'**
  String get merchDeleteTitle;

  /// No description provided for @merchDeleteMessage.
  ///
  /// In tr, this message translates to:
  /// **'{name} kaydını silmek istediğine emin misin?'**
  String merchDeleteMessage(String name);

  /// No description provided for @merchDeleteSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Personel silindi'**
  String get merchDeleteSuccess;

  /// No description provided for @merchDeleteFailure.
  ///
  /// In tr, this message translates to:
  /// **'Silme işlemi başarısız: {error}'**
  String merchDeleteFailure(String error);

  /// No description provided for @merchEmptyFiltered.
  ///
  /// In tr, this message translates to:
  /// **'Aramana uygun sonuç bulunamadı.'**
  String get merchEmptyFiltered;

  /// No description provided for @merchEmptyDefault.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kayıt yok. Sağ üstteki butondan ekip arkadaşlarını ekleyebilirsin.'**
  String get merchEmptyDefault;

  /// No description provided for @merchRankMerch.
  ///
  /// In tr, this message translates to:
  /// **'Mörş'**
  String get merchRankMerch;

  /// No description provided for @merchRankPlasiyer.
  ///
  /// In tr, this message translates to:
  /// **'Plasiyer'**
  String get merchRankPlasiyer;

  /// No description provided for @merchRankSevkiyat.
  ///
  /// In tr, this message translates to:
  /// **'Sevkiyat'**
  String get merchRankSevkiyat;

  /// No description provided for @merchRankSef.
  ///
  /// In tr, this message translates to:
  /// **'Şef'**
  String get merchRankSef;

  /// No description provided for @merchRankYonetici.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get merchRankYonetici;

  /// No description provided for @announcementsTabAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get announcementsTabAll;

  /// No description provided for @announcementsTabAnnouncements.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get announcementsTabAnnouncements;

  /// No description provided for @announcementsTabSurveys.
  ///
  /// In tr, this message translates to:
  /// **'Anketler'**
  String get announcementsTabSurveys;

  /// No description provided for @announcementsTabCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get announcementsTabCompleted;

  /// No description provided for @completedSurveysEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz tamamlanmış anket yok'**
  String get completedSurveysEmpty;

  /// No description provided for @completedSurveysSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Doldurduğunuz anketler burada görünecek'**
  String get completedSurveysSubtitle;

  /// No description provided for @filterByTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlığa göre ara'**
  String get filterByTitle;

  /// No description provided for @sortByDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarihe göre sırala'**
  String get sortByDate;

  /// No description provided for @sortNewest.
  ///
  /// In tr, this message translates to:
  /// **'En yeni'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In tr, this message translates to:
  /// **'En eski'**
  String get sortOldest;

  /// No description provided for @clearFilters.
  ///
  /// In tr, this message translates to:
  /// **'Filtreleri temizle'**
  String get clearFilters;

  /// No description provided for @announcementTypeAnnouncement.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru'**
  String get announcementTypeAnnouncement;

  /// No description provided for @announcementTypeSurvey.
  ///
  /// In tr, this message translates to:
  /// **'Anket'**
  String get announcementTypeSurvey;

  /// No description provided for @announcementExpired.
  ///
  /// In tr, this message translates to:
  /// **'Süresi doldu'**
  String get announcementExpired;

  /// No description provided for @surveyAlreadyResponded.
  ///
  /// In tr, this message translates to:
  /// **'Bu anketi zaten doldurdunuz. Teşekkürler!'**
  String get surveyAlreadyResponded;

  /// No description provided for @surveyDeadline.
  ///
  /// In tr, this message translates to:
  /// **'Son tarih'**
  String get surveyDeadline;

  /// No description provided for @surveySubmit.
  ///
  /// In tr, this message translates to:
  /// **'Anketi Gönder'**
  String get surveySubmit;

  /// No description provided for @surveyCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı'**
  String get surveyCompleted;

  /// No description provided for @surveyTapToRespond.
  ///
  /// In tr, this message translates to:
  /// **'Anketi doldurmak için dokunun'**
  String get surveyTapToRespond;

  /// No description provided for @surveyTextPlaceholder.
  ///
  /// In tr, this message translates to:
  /// **'Cevabınızı yazın...'**
  String get surveyTextPlaceholder;

  /// No description provided for @surveyTextareaPlaceholder.
  ///
  /// In tr, this message translates to:
  /// **'Detaylı cevabınızı yazın...'**
  String get surveyTextareaPlaceholder;

  /// No description provided for @surveyNumberPlaceholder.
  ///
  /// In tr, this message translates to:
  /// **'Sayı girin'**
  String get surveyNumberPlaceholder;

  /// No description provided for @surveyRequiredFieldsError.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen zorunlu soruları cevaplayın'**
  String get surveyRequiredFieldsError;

  /// No description provided for @surveySubmitSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Anket başarıyla gönderildi. Teşekkürler!'**
  String get surveySubmitSuccess;

  /// No description provided for @surveySubmitError.
  ///
  /// In tr, this message translates to:
  /// **'Anket gönderilemedi: {error}'**
  String surveySubmitError(String error);

  /// No description provided for @required.
  ///
  /// In tr, this message translates to:
  /// **'Zorunlu'**
  String get required;

  /// No description provided for @yes.
  ///
  /// In tr, this message translates to:
  /// **'Evet'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In tr, this message translates to:
  /// **'Hayır'**
  String get no;

  /// No description provided for @goBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri Dön'**
  String get goBack;

  /// No description provided for @surveyClosed.
  ///
  /// In tr, this message translates to:
  /// **'Bu anket kapatılmış'**
  String get surveyClosed;

  /// No description provided for @surveyClosedDescription.
  ///
  /// In tr, this message translates to:
  /// **'Bu anketin süresi dolmuş veya kapatılmış. Artık yanıtlanamaz.'**
  String get surveyClosedDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Yotech';

  @override
  String errorWithMessage(String message) {
    return 'Hata: $message';
  }

  @override
  String get tryAgain => 'Tekrar Dene';

  @override
  String get settingsDefaultDisplayName => 'YOTECH Kullanıcısı';

  @override
  String get settingsDefaultRole => 'Kasa Reyon Personeli';

  @override
  String get settingsTitle => 'Hesabım';

  @override
  String get settingsSectionAccount => 'Hesap';

  @override
  String get settingsSectionOther => 'Diğer';

  @override
  String get settingsPersonalInfoTitle => 'Kişisel Bilgilerim';

  @override
  String get settingsPersonalInfoSubtitle =>
      'Ad, iletişim ve giriş bilgilerini görüntüle';

  @override
  String get settingsTeamTitle => 'Takım arkadaşlarım';

  @override
  String get settingsTeamSubtitle => 'Şubendeki ekip ve bölge müdürü bilgileri';

  @override
  String get settingsLanguageTitle => 'Dil';

  @override
  String settingsLanguageSubtitle(String language) {
    return 'Uygulama dili: $language';
  }

  @override
  String get settingsNotificationsTitle => 'Bildirim Ayarları';

  @override
  String get settingsNotificationsSubtitle =>
      'SKT, depo sevk, duyuru ve görev bildirimlerini yönet';

  @override
  String get settingsContractsTitle => 'Sözleşmeler';

  @override
  String get settingsContractsSubtitle => 'KVKK ve çalışma sözleşmeleri';

  @override
  String settingsVersionLabel(String version) {
    return 'Uygulama Versiyonu $version';
  }

  @override
  String get settingsLogoutButton => 'Çıkış Yap';

  @override
  String get settingsLogoutSuccess => 'Oturum kapatıldı';

  @override
  String get settingsLanguageChanged => 'Dil değiştirildi';

  @override
  String get languageNameTurkish => 'Türkçe';

  @override
  String get languageNameEnglish => 'İngilizce';

  @override
  String get settingsLanguageSheetTitle => 'Dil seçimi';

  @override
  String get settingsLanguageSheetDescription =>
      'Uygulama için kullanmak istediğiniz dili seçin';

  @override
  String get announcementsTitle => 'Duyurular';

  @override
  String announcementsLoadError(String error) {
    return 'Duyurular yüklenemedi: $error';
  }

  @override
  String announcementsAuthor(String author) {
    return 'Hazırlayan: $author';
  }

  @override
  String get announcementsEmptyMessage =>
      'Henüz duyuru yayınlanmamış. Yenilikleri kaçırmamak için bildirimlerini açık tut!';

  @override
  String get relativeJustNow => 'Az önce';

  @override
  String relativeMinutes(int minutes) {
    return '$minutes dk önce';
  }

  @override
  String relativeHours(int hours) {
    return '$hours sa önce';
  }

  @override
  String relativeDays(int days) {
    return '$days gün önce';
  }

  @override
  String get loginErrorTitle => 'Giriş Başarısız';

  @override
  String get dialogOk => 'Tamam';

  @override
  String get loginHeading => 'Giriş Yap';

  @override
  String get loginIdLabel => 'ID / Sicil No';

  @override
  String get loginIdHint => 'Sicil numaranızı girin';

  @override
  String get loginIdEmpty => 'Sicil no boş olamaz';

  @override
  String get loginIdTooShort => 'Sicil no en az 3 karakter olmalı';

  @override
  String get loginPasswordLabel => 'Şifre';

  @override
  String get loginPasswordHint => 'Şifrenizi girin';

  @override
  String get loginPasswordEmpty => 'Şifre boş olamaz';

  @override
  String get loginButton => 'Giriş Yap';

  @override
  String loginVersionLabel(String version) {
    return '$version';
  }

  @override
  String get breaksTitle => 'Vardiya ve Molalar';

  @override
  String get breaksTodayTitle => 'Bugünkü Molalar';

  @override
  String breaksHistoryError(String error) {
    return 'Geçmiş yüklenemedi: $error';
  }

  @override
  String get breaksHighlightsTitle => 'Vardiya Planlama';

  @override
  String get breaksHighlightsDescription =>
      'Yakında vardiya bloklarını sürükle-bırak düzenleyip izin takvimiyle entegre yöneteceksiniz. Şimdilik molalarınızı buradan açıp kapatabilirsiniz.';

  @override
  String get breaksHighlightWeeklyTitle => 'Haftalık Kanban';

  @override
  String get breaksHighlightWeeklyDescription =>
      'Personeli kartlar üzerinde gezdirerek vardiya bloklarını anında ayarlayın.';

  @override
  String get breaksHighlightLeaveTitle => 'İzin Entegrasyonu';

  @override
  String get breaksHighlightLeaveDescription =>
      'Onaylı izinler otomatik olarak takvimden düşer, boş slotlara aday önerilir.';

  @override
  String get breaksHighlightNotificationTitle => 'Bildirimli Değişim';

  @override
  String get breaksHighlightNotificationDescription =>
      'Vardiya değiş tokuş talepleri push bildirimi ile ilgili kişilere düşer.';

  @override
  String get breaksOngoing => 'Devam ediyor';

  @override
  String breaksDurationLabel(String duration) {
    return 'Süre: $duration';
  }

  @override
  String get breaksEmptyMessage => 'Bugün için kaydedilmiş mola bulunmuyor.';

  @override
  String get breakQuickTitle => 'Molam';

  @override
  String get breakQuickHistory => 'Geçmiş';

  @override
  String breakQuickLoadError(String error) {
    return 'Mola bilgisi alınamadı: $error';
  }

  @override
  String get breakQuickIdle =>
      'Şu anda açık bir mola yok. Başlatmak için aşağıdaki düğmeye dokunun.';

  @override
  String get breakQuickStop => 'Molayı Bitir';

  @override
  String get breakQuickStart => 'Molayı Başlat';

  @override
  String get breakQuickRefreshTooltip => 'Durumu yenile';

  @override
  String get breakQuickEndSuccess => 'Mola sonlandırıldı.';

  @override
  String get breakQuickStartSuccess => 'Mola başlatıldı.';

  @override
  String breakQuickFailure(String error) {
    return 'İşlem başarısız: $error';
  }

  @override
  String breakQuickStartedAt(String time) {
    return 'Mola $time saatinde başladı.';
  }

  @override
  String breakQuickElapsed(String time) {
    return 'Geçen süre: $time';
  }

  @override
  String commonActionFailed(String error) {
    return 'İşlem başarısız: $error';
  }

  @override
  String get commonEdit => 'Düzenle';

  @override
  String get commonDelete => 'Sil';

  @override
  String get commonDismiss => 'Vazgeç';

  @override
  String get merchSearchHint => 'Firma veya isim ara';

  @override
  String get merchTitle => 'Mörş / Plasiyer';

  @override
  String get merchSearchClose => 'Aramayı kapat';

  @override
  String get merchSearchToggle => 'Filtre / Ara';

  @override
  String get merchAddPerson => 'Personel Ekle';

  @override
  String merchLoadError(String error) {
    return 'Mörş listesi yüklenemedi: $error';
  }

  @override
  String get merchEditTitle => 'Personeli Düzenle';

  @override
  String get merchCreateTitle => 'Yeni Personel Ekle';

  @override
  String get merchFieldFirstName => 'İsim';

  @override
  String get merchFieldLastName => 'Soyisim';

  @override
  String get merchFieldCompany => 'Firma adı';

  @override
  String get merchFieldPhone => 'Telefon numarası';

  @override
  String get merchPhoneRequired => 'Telefon gerekli';

  @override
  String get merchPhoneInvalid => 'Geçerli bir numara girin';

  @override
  String get merchFieldRank => 'Rütbe';

  @override
  String get merchUpdateButton => 'Personeli Güncelle';

  @override
  String get merchAddButton => 'Personel Ekle';

  @override
  String merchFieldRequired(String field) {
    return '$field gerekli';
  }

  @override
  String get merchUpdateSuccess => 'Personel güncellendi';

  @override
  String get merchCreateSuccess => 'Personel eklendi';

  @override
  String get merchDeleteTitle => 'Personeli sil';

  @override
  String merchDeleteMessage(String name) {
    return '$name kaydını silmek istediğine emin misin?';
  }

  @override
  String get merchDeleteSuccess => 'Personel silindi';

  @override
  String merchDeleteFailure(String error) {
    return 'Silme işlemi başarısız: $error';
  }

  @override
  String get merchEmptyFiltered => 'Aramana uygun sonuç bulunamadı.';

  @override
  String get merchEmptyDefault =>
      'Henüz kayıt yok. Sağ üstteki butondan ekip arkadaşlarını ekleyebilirsin.';

  @override
  String get merchRankMerch => 'Mörş';

  @override
  String get merchRankPlasiyer => 'Plasiyer';

  @override
  String get merchRankSevkiyat => 'Sevkiyat';

  @override
  String get merchRankSef => 'Şef';

  @override
  String get merchRankYonetici => 'Yönetici';
}

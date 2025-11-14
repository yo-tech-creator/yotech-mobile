# Flutter Login Ekranı - Kurulum Rehberi

## 📦 Dosya Yapısı

Oluşturulan dosyaları projenize şu yapıda yerleştirin:

```
lib/
├── main.dart
│
├── core/
│   └── routing/
│       └── app_router.dart
│
├── shared/
│   └── widgets/
│       └── custom_back_button.dart
│
└── features/
    ├── auth/
    │   ├── domain/
    │   │   ├── models/
    │   │   │   ├── auth_state.dart
    │   │   │   └── user_model.dart
    │   │   ├── providers/
    │   │   │   └── auth_provider.dart
    │   │   └── repositories/
    │   │       └── auth_repository.dart
    │   └── presentation/
    │       └── screens/
    │           └── login_screen.dart
    │
    ├── firma/
    │   └── presentation/
    │       └── screens/
    │           └── firma_panel_screen.dart
    │
    └── grand_admin/
        └── presentation/
            └── screens/
                └── grand_admin_panel_screen.dart
```

## 🚀 Kurulum Adımları

### 1. SQL - Grand Admin Oluşturma

```sql
-- Supabase SQL Editor'da çalıştırın
-- grand_admin_setup.sql dosyasındaki kodu çalıştırın
```

**Test Giriş Bilgileri:**
- ID: `yakup`
- PW: `kuru22`

### 2. Dependencies Ekleme

`pubspec.yaml` dosyasına ekleyin:

```yaml
dependencies:
  flutter_riverpod: ^2.4.9
  supabase_flutter: ^2.0.0
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  build_runner: ^2.4.6
  freezed: ^2.4.5
  json_serializable: ^6.7.1
```

Terminalde çalıştırın:
```bash
flutter pub get
```

### 3. Code Generation

Freezed ve JSON Serialization için:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Supabase Yapılandırması

`lib/main.dart` dosyasında Supabase bilgilerinizi güncelleyin:

```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',         // Supabase projenizin URL'i
  anonKey: 'YOUR_SUPABASE_ANON_KEY', // Anon/Public key
);
```

### 5. Assets Ekleme

`assets/images/` klasörü oluşturun ve logo ekleyin:

```
your_project/
├── assets/
│   └── images/
│       └── logo.png
```

## 🎯 Özellikler

### ✅ DRY Prensibi
- Geri butonu tek bir merkezi widget'tan (`CustomBackButton`) yönetiliyor
- Login ekranı özel geri butonu (`LoginBackButton`) ile çıkış onayı alıyor

### ✅ Login Akışı
1. Kullanıcı ID ve şifre girer
2. `AuthRepository` ile doğrulama yapılır
3. Kullanıcı tipi kontrol edilir:
   - **Grand Admin** → `/grand-admin` sayfası
   - **Firma kullanıcısı** → `/firma` sayfası

### ✅ Auth State Management
- `Riverpod` ile state yönetimi
- `Freezed` ile immutable state modelleri
- Login/Logout/CurrentUser işlemleri

## 🔐 Güvenlik Notları

### Üretim İçin Yapılması Gerekenler:

1. **Şifre Hash'leme:**
```dart
// Şu anki: Hardcoded şifre kontrolü
if (id == 'yakup' && password == 'kuru22')

// Üretim: Hash karşılaştırması
final hashedPassword = hashPassword(password);
if (user.passwordHash == hashedPassword)
```

2. **JWT Token Yönetimi:**
```dart
// Supabase Auth token'ı otomatik yönetiyor
// Ama custom token ihtiyacı varsa:
final token = await _supabase.auth.currentSession?.accessToken;
```

3. **RLS (Row Level Security):**
```sql
-- Supabase'de her tablo için RLS aktif
-- users tablosu için mevcut
```

## 📱 Kullanım

### Login Ekranı

```dart
// Otomatik olarak main.dart'ta initial route
initialRoute: AppRouter.login,
```

### Firma Paneli

```dart
Navigator.pushReplacementNamed(context, '/firma');
```

### Grand Admin Paneli

```dart
Navigator.pushReplacementNamed(context, '/grand-admin');
```

## 🐛 Sorun Giderme

### "package not found" hatası
```bash
flutter pub get
flutter clean
flutter pub get
```

### Freezed generate hatası
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Supabase bağlantı hatası
- URL ve anonKey'i kontrol edin
- Internet bağlantınızı kontrol edin
- Supabase projenizin aktif olduğundan emin olun

## 📝 Sonraki Adımlar

1. ✅ Login ekranı (Tamamlandı)
2. ✅ Grand Admin sayfası (Boş sayfa)
3. ✅ Firma paneli (Boş sayfa)
4. 🔲 Modül ekleme (SKT, Attendance, vb.)
5. 🔲 Drawer/Menu ekleme
6. 🔲 Profil yönetimi

## 🎉 Test

```bash
# Grand Admin ile giriş
ID: yakup
PW: kuru22

# Yakup Market kullanıcıları
ID: YM-ADMIN-001
Email: yakup.admin@yakupmarket.com
```

---

**Not:** Üretim ortamına geçmeden önce:
- Şifre hash'leme ekleyin
- Hata mesajlarını kullanıcı dostu yapın
- Loading/Error state'leri iyileştirin
- Token refresh mekanizması ekleyin

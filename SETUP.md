# Yotech Mobile App - Setup Talimatları

## 📋 Gereksinimler

- Flutter SDK 3.0.0 veya üzeri
- Dart SDK 3.0.0 veya üzeri
- Android Studio / Xcode (platform-specific development için)

## 🚀 Kurulum Adımları

### 1. Environment Variables Ayarla

`.env.example` dosyasını `.env` olarak kopyala ve Supabase credentials'ını doldur:

```bash
cp .env.example .env
```

`.env` dosyasını düzenle:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

**⚠️ ÖNEMLİ**: `.env` dosyasını asla version control'e commit etme!

### 2. Dependencies Yükle

```bash
flutter pub get
```

### 3. Code Generation Çalıştır

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Uygulamayı Çalıştır

```bash
flutter run
```

## 📱 Proje Yapısı

```
lib/
├── core/
│   ├── features/          # Feature management (tenant-based)
│   └── routing/           # App routing
├── features/
│   ├── auth/              # Authentication
│   ├── home/              # Home shell & bottom navigation
│   ├── skt/               # SKT tracking
│   ├── settings/          # Settings page
│   └── grand_admin/       # Admin panel
├── shared/
│   └── widgets/           # Shared widgets
└── main.dart              # Entry point
```

## 🔐 Güvenlik Notları

- Supabase credentials `.env` dosyasında saklanır
- `.env` dosyası `.gitignore`'da listelenmiştir
- Production için environment-specific `.env` dosyaları kullanın

## 🎯 Özellikler

### Dinamik Feature Management
- Her tenant'ın kendi modül erişimleri vardır
- Özellikler `effectiveFeaturesProvider` tarafından yönetilir
- Kullanıcı rolüne göre otomatik yönlendirme

### Genişleyen Bottom Navigation
- İlk 5 özellik yatay liste olarak gösterilir
- Yukarı sürükleme ile tüm özellikler grid'de görüntülenir
- Kullanıcı adı ve ayarlar butonu alt kısımda

### State Management
- Flutter Riverpod kullanılır
- Type-safe state management
- Async operations için FutureProvider

## 🛠️ Geliştirme

### Yeni Feature Ekleme

1. `lib/features/` altında yeni klasör oluştur
2. Domain/Presentation katmanlarını oluştur
3. `FeatureKeys` class'ına yeni key ekle
4. `_entryFor()` function'ına entry ekle
5. `_buildActivePage()` method'una case ekle

### Code Generation

Model değişiklikleri sonrası:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📝 Notlar

- Tüm UI metinleri Türkçedir
- Material Design 3 kullanılır
- Responsive design desteklenir

## 🐛 Troubleshooting

### `.env` dosyası yüklenmiyor
- `pubspec.yaml`'da `.env` asset olarak listelendiğinden emin ol
- `flutter clean` ve `flutter pub get` çalıştır

### Build hataları
- `flutter clean` çalıştır
- `flutter pub get` çalıştır
- `flutter pub run build_runner build --delete-conflicting-outputs` çalıştır

## 📞 Destek

Sorular veya sorunlar için proje yöneticisine başvur.

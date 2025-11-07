# Yotech Mobile App

Yotech, market/mağaza yönetim sistemi için geliştirilmiş bir Flutter mobil uygulamasıdır. Çok kiracılı (multi-tenant) mimariye sahip olup, her firma kendi özelliklerini dinamik olarak yönetebilir.

## 🎯 Özellikler

### Temel Modüller
- **SKT Takibi** - Ürün takip sistemi
- **Vardiya Yönetimi** - Vardiya planlama ve takibi
- **Form Yönetimi** - Dinamik form doldurma
- **Görev Yönetimi** - Görev atama ve takibi
- **Puantaj** - Giriş/Çıkış takibi (GPS konum ile)
- **Depo Transferi** - Stok transferi yönetimi
- **Arıza Raporları** - Arıza bildirimi ve takibi
- **Duyurular** - Firma duyuruları
- **İzin Talepleri** - İzin yönetimi
- **Mola Takibi** - Mola kayıtları

### Teknik Özellikler
- ✅ Multi-tenant mimarisi
- ✅ Role-based access control (RBAC)
- ✅ Supabase entegrasyonu
- ✅ Flutter Riverpod state management
- ✅ Freezed ile type-safe models
- ✅ RLS (Row Level Security) koruması
- ✅ Genişleyen bottom navigation bar
- ✅ Responsive design

## 📋 Gereksinimler

- Flutter SDK 3.0.0+
- Dart SDK 3.0.0+
- Android Studio / Xcode
- Supabase hesabı

## 🚀 Kurulum

### 1. Repository'yi klonla
```bash
git clone https://github.com/[USERNAME]/yotech-mobile.git
cd yotech-mobile
```

### 2. Environment variables ayarla
```bash
cp .env.example .env
```

`.env` dosyasını düzenle ve Supabase credentials'ını ekle:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### 3. Dependencies yükle
```bash
flutter pub get
```

### 4. Code generation çalıştır
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 5. Uygulamayı çalıştır
```bash
flutter run
```

## 📁 Proje Yapısı

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

## 🔐 Güvenlik

- Supabase credentials `.env` dosyasında saklanır
- `.env` dosyası `.gitignore`'da listelenmiştir
- RLS (Row Level Security) ile veri koruması
- Role-based access control (RBAC)
- Tenant isolation

## 📚 Dokumentasyon

- [SETUP.md](./SETUP.md) - Detaylı kurulum rehberi
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Sorun giderme
- [DEBUG_GUIDE.md](./DEBUG_GUIDE.md) - Debug rehberi
- [SUPABASE_SCHEMA_ANALYSIS.md](./SUPABASE_SCHEMA_ANALYSIS.md) - Veritabanı şeması
- [IMPROVEMENTS.md](./IMPROVEMENTS.md) - Yapılan iyileştirmeler

## 🛠️ Teknoloji Stack

- **Framework**: Flutter 3.0+
- **State Management**: Flutter Riverpod
- **Backend**: Supabase (PostgreSQL + Auth)
- **Code Generation**: Freezed, JSON Serializable
- **UI**: Material Design 3

## 👥 Roller

- **Grand Admin** - Sistem yöneticisi
- **Firma Admin** - Firma yöneticisi
- **Bölge Müdürü** - Bölge yöneticisi
- **Şube Müdürü** - Şube yöneticisi
- **Personel** - Normal çalışan

## 📝 Lisans

Bu proje özel kullanım içindir.

## 📞 İletişim

Sorular veya öneriler için proje yöneticisine başvurun.

---

**Son Güncelleme**: 2024

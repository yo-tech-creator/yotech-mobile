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
    - **Merch/plasiyer** - Mörş destek
- **Mola takip** - Mola takip
- **izin talep** izin talebinde bulunma
- **Mağaza içi eksik** - Kullanıcı kendine hazırladığı eksik listesi





## Not - README ↔ modules mapping
Bazı kısa başlıkların arka plandaki veritabanı tabloları / modül kodlarıyla eşleşmesi için örnek eşlemeler:

- `Depo Transferi` => `inventory_transfers`
- `Arıza Raporları` => `malfunction_reports`  
- `İzin Talepleri` => `leave_requests`

Eğer `modules.code` ile birebir eşleşme istersen, sabitleri (ör. `FeatureKeys`) bu değerlerle güncelleyebilirim.




  
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

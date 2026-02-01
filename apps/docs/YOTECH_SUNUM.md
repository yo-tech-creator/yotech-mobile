# 🚀 YOTECH - Akıllı Mağaza Yönetim Platformu

## Kurumsal Sunum

---

# 📌 Yönetici Özeti

**YOTECH**, perakende sektörü için geliştirilmiş kapsamlı bir **mağaza yönetim platformudur**. Çok kiracılı (multi-tenant) mimarisi sayesinde birden fazla firma tek bir platform üzerinden yönetilebilir.

### Temel Değer Önerisi

| Sorun | YOTECH Çözümü |
|-------|---------------|
| Dağınık Excel tabloları | Merkezi dijital platform |
| Manuel SKT takibi | Otomatik son kullanma tarihi uyarıları |
| Kağıt bazlı formlar | Dijital form sistemi |
| Telefon/WhatsApp iletişimi | Entegre duyuru ve görev sistemi |
| Personel takip zorluğu | GPS destekli puantaj sistemi |
| Şubeler arası koordinasyon eksikliği | Gerçek zamanlı transfer modülü |

---

# 🎯 Platform Özellikleri

## 📱 Mobil Uygulama (Flutter)

### 1. SKT Takibi (Son Kullanma Tarihi)
- **Barkod tarama** ile hızlı ürün girişi
- **Otomatik alarm sistemi** - Belirlenen gün öncesinde uyarı
- **Renk kodlu liste** - Normal / Yaklaşan / Geçmiş durumları
- **Toplu işlem** - Birden fazla ürünü tek seferde işaretleme
- **Raporlama** - Şube bazlı SKT durumu analizi

### 2. Vardiya Yönetimi
- **Esnek vardiya planlaması** - Haftalık/aylık görünüm
- **GPS destekli giriş/çıkış** - Lokasyon doğrulama
- **Geofence kontrolü** - Mağaza sınırları içinde işlem zorunluluğu
- **Otomatik süre hesaplama** - Çalışma saatleri ve fazla mesai
- **Mola takibi** - Mola başlatma/bitirme kayıtları

### 3. Görev Yönetimi
- **Hiyerarşik görev ataması** - Merkez → Bölge → Şube → Personel
- **Öncelik seviyeleri** - Düşük, Orta, Yüksek, Acil
- **İlerleme takibi** - Yüzdelik tamamlanma oranı
- **Fotoğraflı kanıt** - Görev tamamlama belgesi
- **Bildirim sistemi** - Yeni görev ve deadline hatırlatmaları

### 4. Form Sistemi
- **Dinamik form oluşturucu** - Sürükle-bırak tasarım
- **Puanlama sistemi** - Olumlu/Olumsuz değerlendirme
- **Excel import/export** - Toplu form yükleme
- **Versiyon kontrolü** - Form geçmişi ve karşılaştırma
- **Rol bazlı görünürlük** - Hangi rollerin göreceğini belirleme

### 5. Duyuru ve Anketler
- **Hedefli duyurular** - Firma/Bölge/Şube/Rol bazlı
- **Anket modülü** - Çoktan seçmeli ve açık uçlu sorular
- **Okunma takibi** - Kim okudu, kim okumadı
- **Zamanlama** - İleri tarihli yayın ve son kullanma tarihi
- **Dosya ekleri** - PDF, resim desteği

### 6. Depo Transferleri
- **Eksik/Fazla bildirimi** - Şubeler arası stok dengeleme
- **Teklif sistemi** - Şubeler birbirine ürün teklif edebilir
- **Onay mekanizması** - Şube müdürü onayı zorunlu
- **Transfer takibi** - Hazırlanıyor → Gönderildi → Teslim Alındı
- **Bildirimler** - Anlık teklif ve kabul bildirimleri

### 7. Arıza Bildirimi
- **Kategori bazlı raporlama** - Elektrik, Mekanik, Yazılım, Diğer
- **Öncelik belirleme** - Düşük → Acil
- **Fotoğraf desteği** - Arıza görüntüsü ekleme
- **Durum takibi** - Açık → Devam Ediyor → Kapatıldı
- **Atama sistemi** - Sorumlu teknik ekip ataması

### 8. İzin Talep Sistemi
- **Dijital başvuru** - Kağıtsız izin talebi
- **Onay hiyerarşisi** - Şube Müdürü → Bölge Müdürü
- **İzin türleri** - Yıllık, Hastalık, İzinsiz, Diğer
- **Bakiye takibi** - Kalan izin günleri
- **Takvim entegrasyonu** - Şube izin takvimi

### 9. Mörş (Merchandising)
- **Raf düzeni kontrolü** - Planogram uyumu
- **Fotoğraflı raporlama** - Önce/sonra karşılaştırması
- **Checklist sistemi** - Standart kontrol noktaları
- **Puanlama** - Mağaza görünüm skoru

### 10. Stoksuz Ürün Bildirimi
- **Hızlı barkod tarama** - Eksik ürün bildirimi
- **Otomatik sipariş önerisi** - Geçmiş verilere dayalı
- **Merkeze raporlama** - Toplu eksiklik analizi

---

## 💻 Web Yönetim Paneli (Next.js)

### Grand Admin Özellikleri
- **Çoklu firma yönetimi** - Tüm tenant'ları tek ekrandan kontrol
- **Firma oluşturma sihirbazı** - Excel şablonlarıyla toplu kurulum
- **Modül aktivasyonu** - Firma bazlı özellik açma/kapama
- **Sistem monitörü** - Kullanım istatistikleri ve loglar

### Firma Admin Özellikleri
- **Şube yönetimi** - Şube ekleme, düzenleme, pasifleştirme
- **Bölge yapılandırması** - Bölge müdürü ataması
- **Personel yönetimi** - Toplu kullanıcı import/export
- **Ürün kataloğu** - Barkod ve alt barkod yönetimi
- **Form tasarımı** - Özel değerlendirme formları oluşturma
- **Duyuru yönetimi** - Hedefli duyuru ve anket oluşturma
- **Raporlar** - Detaylı analiz ve export

### Bölge Müdürü Özellikleri
- **Çoklu şube görünümü** - Sorumlu olduğu şubeleri yönetme
- **Performans karşılaştırması** - Şubeler arası kıyaslama
- **Onay yönetimi** - İzin ve transfer onayları
- **Görev dağıtımı** - Şubelere görev ataması

### Şube Müdürü Özellikleri
- **Şube dashboard'u** - Günlük özet ve uyarılar
- **Personel takibi** - Puantaj ve performans
- **Stok yönetimi** - SKT ve transfer işlemleri
- **Görev takibi** - Ekip görevleri ve ilerleme

---

# 🔐 Güvenlik Mimarisi

## Çok Katmanlı Güvenlik

### 1. Kimlik Doğrulama (Authentication)
```
┌─────────────────────────────────────────────┐
│           Supabase Auth                      │
├─────────────────────────────────────────────┤
│ • Email/Password authentication              │
│ • JWT token bazlı oturum yönetimi           │
│ • Otomatik token yenileme                   │
│ • Session timeout (configurable)            │
│ • Multi-device session kontrolü             │
└─────────────────────────────────────────────┘
```

### 2. Yetkilendirme (Authorization)
```
┌─────────────────────────────────────────────┐
│     5 Seviyeli Rol Hiyerarşisi              │
├─────────────────────────────────────────────┤
│ 👑 Grand Admin    → Tüm sistem              │
│ 🏢 Firma Admin    → Kendi firması           │
│ 🗺️ Bölge Müdürü   → Sorumlu bölgeler        │
│ 🏪 Şube Müdürü    → Kendi şubesi            │
│ 👤 Personel       → Kendi kayıtları         │
└─────────────────────────────────────────────┘
```

### 3. Row Level Security (RLS)
```sql
-- Her kullanıcı sadece kendi tenant'ının verilerine erişebilir
tenant_id = current_tenant_id()

-- Bölge müdürü sadece kendi bölgesindeki şubeleri görür
branch_id IN (
  SELECT b.id FROM branches b 
  JOIN regions r ON r.id = b.region_id 
  WHERE r.manager_id = current_user_id()
)

-- Personel sadece kendi kayıtlarını görür
created_by = current_user_id()
```

### 4. Veri İzolasyonu
- **Tenant İzolasyonu**: Firmalar birbirinin verilerine erişemez
- **Şube İzolasyonu**: Şubeler izinsiz diğer şube verilerine erişemez
- **Kullanıcı İzolasyonu**: Personel sadece kendi kayıtlarını görür

### 5. API Güvenliği
- **HTTPS zorunluluğu** - Tüm iletişim şifreli
- **Rate limiting** - DDoS koruması
- **Input validation** - SQL injection koruması
- **CORS policy** - İzinli domainler

### 6. Mobil Güvenlik
- **Secure storage** - Hassas verilerin şifreli saklanması
- **Certificate pinning** - Man-in-the-middle saldırı koruması
- **Jailbreak/Root detection** - Güvenilmeyen cihaz uyarısı
- **Biometric authentication** - Parmak izi/Yüz tanıma (opsiyonel)

---

# 📊 Teknik Altyapı

## Mimari Diyagram

```
┌──────────────────────────────────────────────────────────────┐
│                        KULLANICILAR                          │
│  📱 Mobil App (Flutter)    💻 Web Panel (Next.js)            │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                      SUPABASE CLOUD                          │
├──────────────────────────────────────────────────────────────┤
│  🔐 Auth     │  🗄️ Database    │  📁 Storage   │  ⚡ Realtime │
│  (JWT)       │  (PostgreSQL)   │  (S3)         │  (WebSocket) │
├──────────────────────────────────────────────────────────────┤
│  🛡️ RLS Policies  │  🔧 Edge Functions  │  📊 Analytics      │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    VERİTABANI KATMANI                        │
├──────────────────────────────────────────────────────────────┤
│  50+ Tablo  │  100+ RLS Policy  │  30+ Function  │  Triggers │
└──────────────────────────────────────────────────────────────┘
```

## Teknoloji Stack

| Katman | Teknoloji | Neden? |
|--------|-----------|--------|
| **Mobil** | Flutter 3.0+ | Cross-platform, tek kod tabanı |
| **Web** | Next.js 15 | SSR, SEO, performans |
| **State** | Riverpod | Type-safe, testable |
| **Backend** | Supabase | Realtime, RLS, ölçeklenebilir |
| **Database** | PostgreSQL | ACID, JSON, Full-text search |
| **Auth** | Supabase Auth | JWT, OAuth, MFA desteği |
| **Storage** | Supabase Storage | CDN, resim optimizasyonu |

---

# 💼 Firmaya Sağlanan Faydalar

## 💰 Maliyet Tasarrufu

| Alan | Geleneksel | YOTECH ile | Tasarruf |
|------|-----------|-----------|----------|
| SKT kayıpları | Aylık ₺50,000 | Aylık ₺5,000 | **%90** |
| Kağıt/Form maliyeti | Aylık ₺10,000 | ₺0 | **%100** |
| Manuel raporlama | 40 saat/ay | 2 saat/ay | **%95** |
| İletişim maliyeti | Aylık ₺5,000 | ₺500 | **%90** |

## ⏱️ Zaman Tasarrufu

- **SKT kontrolü**: 2 saat → 15 dakika (%87 azalma)
- **Vardiya planlaması**: 4 saat → 30 dakika (%87 azalma)
- **Raporlama**: Anlık, otomatik, gerçek zamanlı
- **İletişim**: Merkezi, takip edilebilir, kayıtlı

## 📈 Verimlilik Artışı

- **Stok devir hızı**: %20 artış (transfer modülü sayesinde)
- **Personel verimliliği**: %30 artış (görev takibi sayesinde)
- **Müşteri memnuniyeti**: %15 artış (rafta bulunurluk)
- **Fire oranı**: %40 azalma (SKT takibi sayesinde)

## 🎯 Stratejik Faydalar

1. **Veri Odaklı Karar Alma**
   - Gerçek zamanlı dashboard'lar
   - Trend analizi ve tahminleme
   - Performans karşılaştırması

2. **Operasyonel Mükemmellik**
   - Standart süreçler
   - Otomatik kontroller
   - Hata minimizasyonu

3. **Ölçeklenebilirlik**
   - Yeni şube açılışı: Dakikalar içinde
   - Yeni personel: Otomatik provisioning
   - Yeni modül: Anında aktivasyon

4. **Rekabet Avantajı**
   - Hızlı karar alma
   - Proaktif stok yönetimi
   - Üstün müşteri deneyimi

---

# 💳 Fiyatlandırma Önerisi

## Model 1: Şube Başına Abonelik

| Paket | Şube Limiti | Modüller | Fiyat (Aylık) |
|-------|-------------|----------|---------------|
| **Starter** | 1-5 şube | Temel 5 modül | ₺2,500 / şube |
| **Business** | 6-20 şube | Tüm modüller | ₺2,000 / şube |
| **Enterprise** | 21+ şube | Tüm + Özel | ₺1,500 / şube |

### Örnek Hesaplama (20 Şube):
- Business paketi: 20 × ₺2,000 = **₺40,000/ay**
- Kurulum ücreti: **₺50,000** (tek seferlik)
- Yıllık toplam: ₺40,000 × 12 + ₺50,000 = **₺530,000**

---

## Model 2: Kullanıcı Başına Abonelik

| Rol | Fiyat (Aylık/Kullanıcı) |
|-----|-------------------------|
| Grand Admin | ₺500 |
| Firma Admin | ₺400 |
| Bölge Müdürü | ₺350 |
| Şube Müdürü | ₺300 |
| Personel | ₺150 |

### Örnek Hesaplama (100 Personel + 20 Müdür):
- 100 × ₺150 + 20 × ₺300 = **₺21,000/ay**
- Yıllık: **₺252,000**

---

## Model 3: Hibrit Model (Önerilen)

| Bileşen | Fiyat |
|---------|-------|
| **Platform Ücreti** | ₺5,000/ay (sabit) |
| **Şube Başına** | ₺500/ay |
| **Aktif Kullanıcı** | ₺100/ay |
| **Kurulum** | ₺30,000 (tek seferlik) |
| **Eğitim** | ₺10,000 (tek seferlik) |

### Örnek Hesaplama (20 Şube, 150 Kullanıcı):
- Platform: ₺5,000
- Şubeler: 20 × ₺500 = ₺10,000
- Kullanıcılar: 150 × ₺100 = ₺15,000
- **Aylık Toplam: ₺30,000**
- **Yıllık: ₺360,000 + ₺40,000 kurulum = ₺400,000**

---

## Ek Hizmetler

| Hizmet | Fiyat |
|--------|-------|
| Özel modül geliştirme | ₺50,000+ |
| SAP/ERP entegrasyonu | ₺100,000+ |
| 7/24 destek | +%20 |
| SLA garantisi (99.9%) | +%15 |
| Özel eğitim | ₺5,000/gün |
| Danışmanlık | ₺2,000/saat |

---

## ROI Hesaplama

### Yatırım (İlk Yıl)
- Yazılım: ₺400,000
- Toplam: **₺400,000**

### Tasarruf (Yıllık)
- SKT kayıp azalması: ₺540,000
- Operasyonel verimlilik: ₺200,000
- Kağıt/iletişim: ₺100,000
- Toplam: **₺840,000**

### Net Fayda
- İlk yıl: ₺840,000 - ₺400,000 = **₺440,000**
- **ROI: %110 (11 ay geri ödeme)**

---

# 📞 İletişim

## Demo Talebi
Canlı demo için bizimle iletişime geçin.

## Teknik Sorular
Teknik ekibimiz sorularınızı yanıtlamak için hazır.

---

# 📎 Ekler

## A. Desteklenen Cihazlar
- **iOS**: iPhone 8 ve üzeri (iOS 14+)
- **Android**: Android 8.0+ cihazlar
- **Web**: Chrome, Firefox, Safari, Edge (son 2 versiyon)

## B. Entegrasyon Seçenekleri
- REST API
- Webhook desteği
- SAP entegrasyonu (opsiyonel)
- Excel import/export

## C. Veri Güvenliği Sertifikaları
- KVKK uyumlu
- SSL/TLS şifreleme
- Düzenli güvenlik denetimleri
- Yedekleme politikası (günlük)

---

**© 2026 YOTECH - Akıllı Mağaza Yönetim Platformu**

*Bu doküman gizlidir ve sadece yetkili kişilerle paylaşılmalıdır.*

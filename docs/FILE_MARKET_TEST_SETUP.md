# FILE MARKET TEST DATA - Kurulum Rehberi

## 🎯 Proje Özeti

Bu rehber, File Market firması için test verileri oluşturmayı ve uygulamayı test etmeyi içerir.

### Oluşturulacaklar:
- **1 Bölge** (Marmara)
- **5 Şube** (İstanbul Anadolu, İstanbul Avrupa, Bursa, İzmit, Sakarya)
- **17 Personel** (1 Firma Admin, 1 Bölge Müdürü, 15 Şube Müdürü)
- **20 Ürün** (Süt, et, sebze, temel gıda, içecek, temizlik)
- **50 SKT Kaydı** (Her şube için 10'ar adet)

---

## 📋 Adım Adım Kurulum

### 1️⃣ SQL Scriptlerini Çalıştır

Supabase Dashboard → SQL Editor'de sırayla çalıştır:

#### a) Bölge, Şubeler ve Ürünler
```bash
FILE_MARKET_TEST_DATA.sql
```

#### b) Kullanıcılar (17 Personel)
```bash
FILE_MARKET_USERS.sql
```

#### c) SKT Kayıtları
```bash
FILE_MARKET_SKT_RECORDS.sql
```

#### d) Personel Ekleme Fonksiyonu
```bash
ADD_PERSONEL_FUNCTION.sql
```

---

### 2️⃣ Test Kullanıcıları

Tüm kullanıcılar için şifre: **test123456**

#### 👤 Firma Admin
- **Email:** fileadmin@filemarket.com
- **Employee Code:** FILEADM001
- **Rol:** Firma Yöneticisi

#### 👤 Bölge Müdürü
- **Email:** bolgemuduru@filemarket.com
- **Employee Code:** FILEBM001
- **Rol:** Bölge Müdürü

#### 👥 Şube Müdürleri (15 kişi)

**İstanbul Anadolu (3):**
- istan1@filemarket.com (ISTAN001)
- istan2@filemarket.com (ISTAN002)
- istan3@filemarket.com (ISTAN003)

**İstanbul Avrupa (3):**
- istav1@filemarket.com (ISTAV001)
- istav2@filemarket.com (ISTAV002)
- istav3@filemarket.com (ISTAV003)

**Bursa (3):**
- bursa1@filemarket.com (BURSA001)
- bursa2@filemarket.com (BURSA002)
- bursa3@filemarket.com (BURSA003)

**İzmit (3):**
- izmit1@filemarket.com (IZMIT001)
- izmit2@filemarket.com (IZMIT002)
- izmit3@filemarket.com (IZMIT003)

**Sakarya (3):**
- sakarya1@filemarket.com (SAKAR001)
- sakarya2@filemarket.com (SAKAR002)
- sakarya3@filemarket.com (SAKAR003)

---

### 3️⃣ Flutter Uygulamasını Test Et

```bash
cd C:\flutter_projects\yotech2\apps\mobile
flutter run
```

#### Login Testi:
1. **Sicil No:** FILEADM001
2. **Şifre:** test123456

---

## 🎨 Uygulama Özellikleri

### ✅ Tüm Roller İçin:
- **Kullanıcı Bilgileri:** İsim, email, rol, sicil no
- **SKT Kayıtları:** En yakın 2 SKT kaydı gösterilir
- **Durum Renkleri:**
  - 🔴 Kırmızı: Geçmiş
  - 🟠 Turuncu: Yaklaşan
  - 🟢 Yeşil: Normal

### ✅ Firma Admin İçin Ek Özellik:
- **Personel Ekleme Formu:**
  - Employee Code girilir
  - Password girilir
  - Otomatik random isim, email, telefon oluşturulur
  - Tek tuşla yeni personel eklenir

---

## 🔍 Kontrol Sorguları

### Kullanıcı Sayısını Kontrol Et
```sql
SELECT 
  role::text as rol,
  COUNT(*) as sayi
FROM users 
WHERE tenant_id = '11111111-1111-1111-1111-111111111111'
GROUP BY role
ORDER BY role;
```

Beklenen Sonuç:
```
firma_admin     | 1
bolge_muduru    | 1
sube_muduru     | 15
```

### SKT Durumlarını Kontrol Et
```sql
SELECT 
  status::text as durum,
  COUNT(*) as sayi
FROM skt_records 
WHERE tenant_id = '11111111-1111-1111-1111-111111111111'
GROUP BY status
ORDER BY status;
```

### Şube Bazında SKT Sayıları
```sql
SELECT 
  b.name as sube,
  COUNT(s.id) as skt_sayisi
FROM branches b
LEFT JOIN skt_records s ON s.branch_id = b.id
WHERE b.tenant_id = '11111111-1111-1111-1111-111111111111'
GROUP BY b.name
ORDER BY b.name;
```

---

## 🧪 Test Senaryoları

### Test 1: Firma Admin Girişi
1. Login: FILEADM001 / test123456
2. Ekranda görünmeli:
   - ✅ Ahmet Yıldırım
   - ✅ Firma Yöneticisi
   - ✅ 2 adet SKT kaydı (farklı şubelerden)
   - ✅ Personel ekleme formu

### Test 2: Şube Müdürü Girişi
1. Login: ISTAN001 / test123456
2. Ekranda görünmeli:
   - ✅ Personel İst Anadolu 1
   - ✅ Mağaza Sorumlusu
   - ✅ 2 adet SKT kaydı (sadece kendi şubesinden)
   - ❌ Personel ekleme formu (yok)

### Test 3: Yeni Personel Ekleme
1. Firma admin olarak giriş yap
2. Personel Ekleme Formu'na:
   - Employee Code: TEST999
   - Password: test123456
3. "Personel Ekle" butonuna bas
4. Başarılı mesajı görünmeli
5. Yeni personel ile login testi:
   - Sicil No: TEST999
   - Şifre: test123456

---

## 🐛 Sorun Giderme

### Hata: "employee_code already exists"
**Çözüm:** Farklı bir employee code kullanın veya mevcut kaydı silin:
```sql
DELETE FROM auth.users WHERE email = 'test999@filemarket.com';
DELETE FROM users WHERE employee_code = 'TEST999';
```

### Hata: "RPC function not found"
**Çözüm:** ADD_PERSONEL_FUNCTION.sql dosyasını çalıştırın.

### SKT Kayıtları Görünmüyor
**Kontrol:**
```sql
SELECT COUNT(*) FROM skt_records 
WHERE tenant_id = '11111111-1111-1111-1111-111111111111';
```
Sonuç 50 olmalı. Değilse FILE_MARKET_SKT_RECORDS.sql'i tekrar çalıştırın.

---

## 📊 Veri İstatistikleri

### Ürün Kategorileri
- Süt Ürünleri: 4
- Et Ürünleri: 3
- Sebze/Meyve: 3
- Temel Gıda: 4
- İçecekler: 3
- Temizlik: 3
**Toplam:** 20 ürün

### Personel Dağılımı
- Firma Admin: 1
- Bölge Müdürü: 1
- Şube Müdürü: 15
**Toplam:** 17 personel

### SKT Durumu
- Geçmiş: ~10 kayıt
- Yaklaşan: ~15 kayıt
- Normal: ~25 kayıt
**Toplam:** 50 SKT kaydı

---

## 🚀 Sonraki Adımlar

1. ✅ Temel veri yapısı hazır
2. 🔄 Daha fazla ürün ekleyebilirsiniz
3. 🔄 Gerçek şube konumları güncellenebilir
4. 🔄 Fotoğraf URL'leri eklenebilir
5. 🔄 İzin talepleri, vardiya çizelgeleri eklenebilir

---

## 📞 Destek

Herhangi bir sorun olursa:
1. Console loglarını kontrol edin
2. Supabase Dashboard → Logs kısmına bakın
3. SQL sorgularını tek tek test edin

**İyi testler! 🎉**

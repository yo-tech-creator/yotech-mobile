# 🚀 HIZLI BAŞLANGIÇ - File Market Test

## ⚡ 4 Adımda Kurulum

### 1️⃣ Temizlik (İsteğe bağlı - sadece 2. kez çalıştırıyorsan)
```sql
CLEAN_FILE_MARKET_DATA.sql
```

### 2️⃣ Temel Veri (Bölge, Şube, Ürün)
```sql
FILE_MARKET_TEST_DATA_FIXED.sql
```
✅ Çıktı: 1 bölge, 5 şube, 20 ürün

### 3️⃣ Kullanıcılar (17 personel)
```sql
FILE_MARKET_USERS_FIXED.sql
```
✅ Çıktı: 1 admin, 1 bölge müdürü, 15 şube müdürü

### 4️⃣ SKT Kayıtları (50 adet)
```sql
FILE_MARKET_SKT_RECORDS_FIXED.sql
```
✅ Çıktı: Her şubede 10'ar SKT kaydı

### 5️⃣ Personel Ekleme Fonksiyonu
```sql
ADD_PERSONEL_FUNCTION.sql
```
✅ Çıktı: RPC fonksiyonu aktif

---

## ✅ Test Kullanıcıları

Tüm şifreler: **test123456**

### Firma Admin
- **Sicil:** FILEADM001
- **Email:** fileadmin@filemarket.com

### Bölge Müdürü
- **Sicil:** FILEBM001
- **Email:** bolgemuduru@filemarket.com

### Şube Müdürleri
- ISTAN001, ISTAN002, ISTAN003 (İstanbul Anadolu)
- ISTAV001, ISTAV002, ISTAV003 (İstanbul Avrupa)
- BURSA001, BURSA002, BURSA003 (Bursa)
- IZMIT001, IZMIT002, IZMIT003 (İzmit)
- SAKAR001, SAKAR002, SAKAR003 (Sakarya)

---

## 📱 Flutter Test

```bash
cd C:\flutter_projects\yotech2\apps\mobile
flutter run
```

**Login:**
- Sicil: FILEADM001
- Şifre: test123456

---

## 🐛 Hatalar ve Çözümler

### ❌ "regions already exists"
**Çözüm:** CLEAN_FILE_MARKET_DATA.sql çalıştır

### ❌ "branch_id is ambiguous"
**Çözüm:** FILE_MARKET_SKT_RECORDS_FIXED.sql kullan (eski değil)

### ❌ "Şubeler bulunamadı"
**Çözüm:** Sırasıyla çalıştırdığından emin ol (1→2→3→4)

---

## 📊 Kontrol Sorgusu

```sql
-- Özet bilgi
SELECT 
  'Bölge' as tip, COUNT(*) as sayi FROM regions WHERE tenant_id = '11111111-1111-1111-1111-111111111111'
UNION ALL
SELECT 'Şube', COUNT(*) FROM branches WHERE tenant_id = '11111111-1111-1111-1111-111111111111'
UNION ALL
SELECT 'Ürün', COUNT(*) FROM products WHERE tenant_id = '11111111-1111-1111-1111-111111111111'
UNION ALL
SELECT 'Kullanıcı', COUNT(*) FROM users WHERE tenant_id = '11111111-1111-1111-1111-111111111111'
UNION ALL
SELECT 'SKT Kayıt', COUNT(*) FROM skt_records WHERE tenant_id = '11111111-1111-1111-1111-111111111111';
```

**Beklenen Sonuç:**
```
Bölge       | 1
Şube        | 5
Ürün        | 20
Kullanıcı   | 17
SKT Kayıt   | 50
```

---

## 🎯 Başarı!

Eğer tüm sayılar doğruysa, sistemi test edebilirsin! 🎉

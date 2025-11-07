# Troubleshooting Rehberi

## 🔴 Hata: "Özellikler yüklenemedi - Kullanıcı verisi bulunamadı"

### Olası Nedenler

1. **users tablosunda kayıt yok**
   - Giriş yapan kullanıcı `users` tablosunda bulunmuyor
   - Supabase Auth ile `users` tablosu senkronize değil

2. **tenant_id NULL**
   - Kullanıcı kaydında `tenant_id` boş
   - Kullanıcı hiçbir tenant'a atanmamış

3. **tenants tablosunda kayıt yok**
   - Tenant ID'si yanlış
   - Tenant kaydı silinmiş

4. **RLS (Row Level Security) kuralları**
   - Kullanıcı `users` tablosuna erişemiyor
   - Kullanıcı `tenants` tablosuna erişemiyor

### 🔧 Çözüm Adımları

#### Adım 1: Debug Loglarını Kontrol Et

Terminal'de şu çıktıları ara:

```
📱 DEBUG: userId = [USER_ID]
📱 DEBUG: userData = [USER_DATA]
📱 DEBUG: tenantId = [TENANT_ID]
📱 DEBUG: tenantData = [TENANT_DATA]
```

#### Adım 2: Supabase Console'da Kontrol Et

1. **Supabase Dashboard** açılır
2. **SQL Editor** → Yeni Query

```sql
-- Kullanıcı var mı?
SELECT id, email, tenant_id FROM users WHERE id = '[USER_ID]';

-- Tenant var mı?
SELECT id, name FROM tenants WHERE id = '[TENANT_ID]';

-- Tenant modülleri var mı?
SELECT * FROM tenants WHERE id = '[TENANT_ID]';
```

#### Adım 3: RLS Kurallarını Kontrol Et

1. **Authentication** → **Policies**
2. `users` tablosu için policy kontrol et
3. `tenants` tablosu için policy kontrol et

**Gerekli Policies:**

```sql
-- users tablosu - Kullanıcı kendi kaydını görebilir
CREATE POLICY "Users can view their own data"
ON users FOR SELECT
USING (auth.uid() = id);

-- tenants tablosu - Authenticated kullanıcılar görebilir
CREATE POLICY "Authenticated users can view tenants"
ON tenants FOR SELECT
USING (auth.role() = 'authenticated');
```

#### Adım 4: Veri Yapısını Kontrol Et

**users tablosu şu sütunları içermeli:**
- `id` (UUID, Primary Key)
- `email` (Text)
- `first_name` (Text)
- `last_name` (Text)
- `role` (Text)
- `tenant_id` (UUID, Foreign Key)
- `branch_id` (UUID, nullable)
- `employee_code` (Text, nullable)
- `active` (Boolean)

**tenants tablosu şu sütunları içermeli:**
- `id` (UUID, Primary Key)
- `name` (Text)
- `module_skt` (Boolean)
- `module_forms` (Boolean)
- `module_shifts` (Boolean)
- `module_announcements` (Boolean)
- `module_tasks` (Boolean)
- `module_interbranch_transfer` (Boolean)
- `module_leave_request` (Boolean)
- `module_break_tracking` (Boolean)
- `module_it_ticket` (Boolean)
- `module_instore_shortage` (Boolean)
- `module_time_attendance` (Boolean)
- `module_merchandising` (Boolean)

### 📋 Kontrol Listesi

- [ ] Supabase URL ve Key doğru (`.env` dosyasında)
- [ ] `users` tablosu var ve veri içeriyor
- [ ] `tenants` tablosu var ve veri içeriyor
- [ ] Kullanıcı `users` tablosunda kayıtlı
- [ ] Kullanıcının `tenant_id` dolu
- [ ] Tenant kaydı `tenants` tablosunda var
- [ ] RLS policies doğru ayarlanmış
- [ ] Supabase Auth ile `users` tablosu senkronize

### 🆘 Hala Çalışmıyorsa

1. **Flutter clean çalıştır**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Debug loglarını paylaş**
   - Terminal çıktısını kopyala
   - `📱 DEBUG:` ile başlayan satırları gönder

3. **Supabase SQL çıktısını paylaş**
   - Yukarıdaki SQL sorgularının sonuçlarını gönder

---

## 🔴 Diğer Hatalar

### "Giriş başarısız - Kullanıcı bulunamadı"

**Sebep**: `get_user_email_by_sicil` RPC fonksiyonu yok veya çalışmıyor

**Çözüm**: Supabase'de RPC fonksiyonunu oluştur:

```sql
CREATE OR REPLACE FUNCTION get_user_email_by_sicil(p_sicil_no TEXT)
RETURNS TABLE(email TEXT, active BOOLEAN) AS $$
BEGIN
  RETURN QUERY
  SELECT u.email, u.active
  FROM users u
  WHERE u.employee_code = p_sicil_no;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### "Giriş başarısız - Şifre hatalı"

**Sebep**: Email veya şifre yanlış

**Çözüm**: 
- Sicil no doğru mu?
- Şifre doğru mu?
- Kullanıcı aktif mi?

### ".env dosyası yüklenmiyor"

**Sebep**: `flutter_dotenv` paketi yüklenmemiş

**Çözüm**:
```bash
flutter pub get
flutter clean
flutter pub get
```

---

## 📞 Destek

Sorular için debug loglarını ve Supabase SQL çıktılarını paylaş.

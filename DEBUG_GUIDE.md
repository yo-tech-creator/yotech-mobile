# Debug Rehberi

## 🔍 Hata Ayıklama Adımları

### 1. Terminal Çıktısını Kontrol Et

Uygulamayı çalıştırdığında terminal'de şu debug mesajlarını ara:

```
📱 DEBUG: userId = [USER_ID]
📱 DEBUG: userData = [USER_DATA]
📱 DEBUG: tenantId = [TENANT_ID]
📱 DEBUG: tenantData = [TENANT_DATA]
```

**Eğer bu mesajlar görünmüyorsa:**
- Giriş başarısız olmuş
- Kullanıcı oturumu kapalı

### 2. Fallback Modu

Eğer veritabanı sorgusu başarısız olursa:

```
⚠️ FALLBACK: Tüm özellikler aktif edildi (geliştirme modu)
```

Bu durumda **tüm özellikler aktif** olur ve uygulamayı test edebilirsin.

### 3. Supabase Bağlantısını Test Et

```dart
// main.dart'ta şu kodu ekle (test için)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  // Supabase test
  print('🔗 Supabase URL: ${dotenv.env['SUPABASE_URL']}');
  print('🔑 Supabase Key: ${dotenv.env['SUPABASE_ANON_KEY']?.substring(0, 20)}...');
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  
  print('✅ Supabase başlatıldı');
  
  runApp(...);
}
```

### 4. Veritabanı Sorgularını Test Et

Supabase Console'da test et:

```sql
-- Test 1: users tablosu var mı?
SELECT COUNT(*) FROM users;

-- Test 2: tenants tablosu var mı?
SELECT COUNT(*) FROM tenants;

-- Test 3: Örnek kullanıcı var mı?
SELECT id, email, tenant_id FROM users LIMIT 1;

-- Test 4: Örnek tenant var mı?
SELECT id, name FROM tenants LIMIT 1;
```

### 5. RLS Policies Kontrol Et

```sql
-- users tablosu policies
SELECT * FROM pg_policies WHERE tablename = 'users';

-- tenants tablosu policies
SELECT * FROM pg_policies WHERE tablename = 'tenants';
```

## 📊 Debug Mesajları Açıklaması

| Mesaj | Anlamı | Çözüm |
|-------|--------|-------|
| `📱 DEBUG: userId = null` | Kullanıcı oturumu yok | Giriş yap |
| `📱 DEBUG: userData = null` | users tablosunda kayıt yok | Kullanıcı kaydı oluştur |
| `📱 DEBUG: tenantId = null` | tenant_id boş | Kullanıcıya tenant ata |
| `📱 DEBUG: tenantData = null` | tenants tablosunda kayıt yok | Tenant kaydı oluştur |
| `❌ DEBUG: PostgrestException` | Veritabanı hatası | RLS policies kontrol et |
| `⚠️ FALLBACK: Tüm özellikler aktif` | Fallback modu aktif | Veritabanı sorgusu başarısız |

## 🧪 Test Senaryoları

### Senaryo 1: Yeni Kullanıcı Kaydı

1. Supabase Console'da `users` tablosuna yeni kayıt ekle
2. `tenant_id` doldur
3. Uygulamada giriş yap
4. Debug mesajlarını kontrol et

### Senaryo 2: Tenant Modülleri

1. `tenants` tablosunda modül flags'lerini değiştir
2. Uygulamayı yeniden başlat
3. Bottom bar'da özellikler değişti mi?

### Senaryo 3: RLS Policies

1. RLS policy'yi kaldır
2. Uygulamayı test et
3. RLS policy'yi geri ekle

## 🔧 Geliştirme İpuçları

### Debug Loglarını Kapat (Production)

```dart
// feature_repo.dart
if (kDebugMode) {
  print('📱 DEBUG: userId = $userId');
}
```

### Fallback Modunu Kapat (Production)

```dart
// feature_repo.dart
// Fallback kodu kaldır veya condition ekle
if (kDebugMode) {
  // Fallback modu sadece debug'da
}
```

### Custom Logger Ekle

```dart
// lib/core/logger.dart
class AppLogger {
  static void debug(String message) {
    if (kDebugMode) {
      print('📱 DEBUG: $message');
    }
  }
  
  static void error(String message) {
    print('❌ ERROR: $message');
  }
}
```

## 📝 Kontrol Listesi

- [ ] `.env` dosyası doğru
- [ ] Supabase URL ve Key doğru
- [ ] `users` tablosu var
- [ ] `tenants` tablosu var
- [ ] Kullanıcı kaydı var
- [ ] Tenant kaydı var
- [ ] RLS policies doğru
- [ ] Debug mesajları görünüyor
- [ ] Fallback modu çalışıyor

## 🆘 Hala Çalışmıyorsa

1. **Flutter clean çalıştır**
   ```bash
   flutter clean
   flutter pub get
   flutter pub run build_runner build
   ```

2. **Emulator/Device'ı yeniden başlat**

3. **Supabase bağlantısını test et**
   ```bash
   # Supabase CLI ile test
   supabase status
   ```

4. **Debug loglarını paylaş**
   - Terminal çıktısını kopyala
   - Supabase SQL sonuçlarını paylaş

---

**Son Güncelleme**: 2024

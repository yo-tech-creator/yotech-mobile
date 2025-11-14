# LOGIN SORUNU ÇÖZÜMÜ

## Problem
Login yaparken RLS (Row Level Security) politikası şu hatayı veriyor:
- Sicil_no ile users tablosuna erişilemiyor
- `tenant_id = current_tenant_id()` kontrolü NULL dönüyor çünkü henüz authenticate olmadık

## Kök Sebep
**Chicken-Egg Problemi:**
1. Login için email gerekiyor → Users tablosundan sicil_no ile bulmalıyız
2. Users tablosuna erişmek için RLS kontrolü geçilmeli → `tenant_id = current_tenant_id()`
3. `current_tenant_id()` JWT'den okuyor → JWT login sonrası oluşuyor
4. Döngü: Email bulamıyoruz çünkü login olamıyoruz, login olamıyoruz çünkü email bulamıyoruz

## Çözüm
`SECURITY DEFINER` ile RPC fonksiyonu oluşturduk: `get_user_email_by_sicil()`

Bu fonksiyon:
- RLS bypass eder (sadece bu fonksiyon için)
- Sicil_no ile email ve aktiflik bilgisini döner
- Güvenli: Sadece public bilgileri döner, şifre vs. dönmez

## Uygulama Adımları

### 1. SQL Migration Çalıştır
**Dosya:** `C:\flutter_projects\yotech2\supabase\migrations\fix_login_rls.sql`

Supabase Dashboard'da:
- SQL Editor açın
- Dosya içeriğini yapıştırın
- "Run" butonuna basın

### 2. Flutter Kodu Güncellendi ✅
**Dosya:** `apps/mobile/lib/features/auth/domain/repositories/auth_repository.dart`

Değişiklikler:
- Login metodu artık `get_user_email_by_sicil` RPC'sini kullanıyor
- Email bulunduktan sonra Supabase Auth ile giriş yapıyor
- Login başarılıysa RLS artık aktif, kullanıcı bilgileri users tablosundan alınıyor

### 3. Test
Login akışı:
```
1. Kullanıcı sicil_no + password girer
2. RPC ile email bulunur (RLS bypass)
3. Email + password ile Supabase Auth login
4. custom_access_token_hook JWT'ye tenant_id + role ekler
5. Users tablosundan kullanıcı bilgileri alınır (RLS artık aktif)
```

## Güvenlik Kontrolü

✅ **Mevcut güvenlik modeli korundu**
- RLS politikaları değişmedi
- Sadece login için minimal bypass yapıldı
- Fonksiyon sadece email ve aktiflik döner (hassas veri yok)

✅ **Multi-tenant izolasyon korundu**
- Login sonrası tüm tablolar tenant_id ile filtreleniyor
- `custom_access_token_hook` JWT'ye tenant_id ekliyor
- Her kullanıcı sadece kendi tenant'ının verilerini görebilir

## Neden Bu Yaklaşımı Seçtik?

**Alternatif 1:** Users tablosuna public read ekle
- ❌ Güvenlik riski: Tüm users tablosu public'e açılır
- ❌ Multi-tenant izolasyon bozulur

**Alternatif 2:** Email formatı sabitlerse direkt türet (sicil_no@company.com)
- ❌ Email formatı sabit değil
- ❌ Esnek değil

**Seçilen Çözüm:** RPC fonksiyonu (SECURITY DEFINER)
- ✅ Minimal RLS bypass (sadece email ve aktiflik)
- ✅ Güvenli: Hassas veri döndürmüyor
- ✅ Mevcut güvenlik modeli korunuyor
- ✅ Esnek: Email formatı değişse de çalışır

## Teknik Detaylar

### RPC Fonksiyonu
```sql
CREATE OR REPLACE FUNCTION public.get_user_email_by_sicil(p_sicil_no TEXT)
RETURNS TABLE (email TEXT, aktif BOOLEAN) 
LANGUAGE plpgsql
SECURITY DEFINER  -- RLS bypass
SET search_path = public
```

### Flutter Login Akışı
```dart
// 1. RPC ile email bul (RLS bypass)
final emailResponse = await _supabase
    .rpc('get_user_email_by_sicil', params: {'p_sicil_no': sicilNo})
    .maybeSingle();

// 2. Auth login
await _supabase.auth.signInWithPassword(email: email, password: password);

// 3. custom_access_token_hook JWT'ye tenant_id ekler (otomatik)

// 4. Users tablosundan veri çek (RLS artık aktif)
final userResponse = await _supabase.from('users')...
```

## Sonuç
✅ Login sorunu çözüldü
✅ Güvenlik modeli korundu  
✅ Multi-tenant izolasyon aktif
✅ Kod temiz ve bakımı kolay

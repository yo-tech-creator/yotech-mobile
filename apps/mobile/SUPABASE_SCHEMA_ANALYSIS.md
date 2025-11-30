# Supabase Şema Analizi

## 📊 Veritabanı Yapısı

Supabase'de aşağıdaki tablolar bulunmaktadır:

### Ana Tablolar

| Tablo | Amaç | Önemli Sütunlar |
|-------|------|-----------------|
| `users` | Kullanıcı yönetimi | id, email, tenant_id, branch_id, employee_code, role, active |
| `tenants` | Firma/Şirket yönetimi | id, name, module_* (12 modül flag'i) |
| `branches` | Şube yönetimi | id, tenant_id, name, code, latitude, longitude, geofence_radius |
| `regions` | Bölge yönetimi | id, tenant_id, name, code, manager_id |

### İş Modülleri

| Tablo | Modül | Açıklama |
|-------|-------|----------|
| `skt_records` | SKT | Ürün takip sistemi |
| `shifts` | Vardiya | Vardiya planlama |
| `form_templates` + `form_submissions` | Formlar | Dinamik form sistemi |
| `announcements` | Duyurular | Duyuru yönetimi |
| `tasks` + `task_items` + `task_assignees` | Görevler | Görev yönetimi |
| `leave_requests` | İzin Talepleri | İzin yönetimi |
| `break_logs` | Mola Takibi | Mola kayıtları |
| `attendance` | Puantaj | Giriş/Çıkış takibi |
| `inventory_transfers` | Depo Transferi | Stok transferi |
| `product_issues` | Ürün Sorunları | Ürün şikayetleri |
| `health_reports` | Sağlık Raporları | Sağlık belgeleri |
| `malfunction_reports` | Arıza Raporları | Arıza bildirimleri |

### Yardımcı Tablolar

- `products` - Ürün kataloğu
- `notifications` - Bildirim sistemi
- `payrolls` - Maaş yönetimi
- `employee_scores` - Çalışan değerlendirmesi
- `branch_scores` - Şube değerlendirmesi
- `announcement_reads` - Duyuru okunma takibi
- `stockout_lists` + `stockout_items` - Stok eksikliği

---

## 🔐 RLS (Row Level Security) Politikaları

### Temel Prensipler

1. **Tenant Isolation**: Her kullanıcı sadece kendi tenant'ının verilerine erişebilir
   ```sql
   tenant_id = current_tenant_id()
   ```

2. **Role-Based Access**: Roller bazında erişim kontrolü
   - `grand_admin` - Tüm sistemin yöneticisi
   - `firma_admin` - Firma yöneticisi
   - `bolge_muduru` - Bölge müdürü
   - `sube_muduru` - Şube müdürü
   - `personel` - Normal çalışan

3. **Branch Filtering**: Çalışanlar sadece kendi şubelerinin verilerine erişebilir
   ```sql
   branch_id IN (SELECT users.branch_id FROM users WHERE users.id = current_user_id())
   ```

### Önemli Policies

| Tablo | Policy | Kural |
|-------|--------|-------|
| `users` | SELECT | `tenant_id = current_tenant_id()` |
| `tenants` | SELECT | `id = current_tenant_id() OR role = 'grand_admin'` |
| `branches` | SELECT | `tenant_id = current_tenant_id()` |
| `announcements` | SELECT | Tenant + (admin VEYA active + not expired) |
| `attendance` | SELECT | Tenant + (admin VEYA kendi branch'i) |

---

## 🔧 PostgreSQL Fonksiyonları

### Güvenlik Fonksiyonları

```sql
-- Mevcut kullanıcı ID'si
current_user_id() -> UUID

-- Mevcut tenant ID'si
current_tenant_id() -> UUID

-- Mevcut kullanıcı rolü
current_user_role() -> TEXT
```

### Veri Alma Fonksiyonları (RLS Bypass)

```sql
-- Sicil no ile email ve aktiflik bilgisi al
get_user_email_by_sicil(p_sicil_no TEXT) 
  -> TABLE(email TEXT, active BOOLEAN)

-- User ID ile tüm kullanıcı verisi al
get_user_data_by_id(p_user_id TEXT)
  -> TABLE(id, email, first_name, last_name, role, tenant_id, branch_id, employee_code)
```

### Hesaplama Fonksiyonları (Triggers)

- `calculate_attendance_minutes()` - Puantaj süresini hesapla
- `calculate_break_duration()` - Mola süresini hesapla
- `calculate_skt_alarm_date()` - SKT alarm tarihini hesapla
- `update_task_completion()` - Görev tamamlanma yüzdesini güncelle
- `update_updated_at_column()` - updated_at otomatik güncelle

---

## 📝 Özel Veri Tipleri (ENUMS)

```sql
-- Kullanıcı Rolleri
user_role: 'grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru', 'personel'

-- Transfer Durumları
transfer_status: 'hazirlaniyor', 'gonderildi', 'teslim_alindi'

-- İzin Türleri
leave_type: 'yillik', 'hastalık', 'izinsiz', 'diğer'

-- İzin Durumları
leave_status: 'beklemede', 'onaylandi', 'reddedildi'

-- Arıza Kategorileri
malfunction_category: 'elektrik', 'mekanik', 'yazılım', 'diğer'

-- Arıza Öncelikleri
malfunction_priority: 'düşük', 'orta', 'yüksek', 'acil'

-- Arıza Durumları
malfunction_status: 'acik', 'devam_ediyor', 'kapatildi'

-- Ürün Sorun Durumları
product_issue_status: 'acik', 'devam_ediyor', 'kapatildi'

-- SKT Durumları
skt_status: 'normal', 'yaklasan', 'gecmis'
```

---

## 🚀 Uygulamada Kullanılan Fonksiyonlar

### Login Akışı

```dart
// 1. Sicil no ile email al
get_user_email_by_sicil(sicilNo)
  -> email, active

// 2. Supabase Auth ile giriş yap
signInWithPassword(email, password)
  -> session

// 3. Kullanıcı verisi al
get_user_data_by_id(userId)
  -> UserModel
```

### Feature Loading

```dart
// 1. Kullanıcı verisi al (RPC)
get_user_data_by_id(userId)
  -> tenant_id

// 2. Tenant modüllerini al (Direct Query)
SELECT module_* FROM tenants WHERE id = tenant_id
  -> Map<String, bool>
```

---

## ⚠️ Önemli Notlar

### RLS Bypass Gereken Durumlar

Aşağıdaki işlemler için RPC fonksiyonları kullanılır (RLS bypass):
- Login sırasında kullanıcı verisi alma
- Sicil no ile email bulma

### Direct Query Kullanılan Durumlar

Aşağıdaki işlemler doğrudan query ile yapılabilir (RLS korumalı):
- Tenant modüllerini alma (authenticated user)
- Kendi verilerini alma
- Kendi branch'inin verilerini alma

### Fallback Modu

Veritabanı sorgusu başarısız olursa:
- Tüm özellikler aktif edilir (geliştirme modu)
- Uygulamayı test etmeye devam edebilirsiniz

---

## 🔍 Debug İpuçları

### Terminal Çıktısını Kontrol Et

```
📱 DEBUG: userId = [USER_ID]
📱 DEBUG: userData = [USER_DATA]
📱 DEBUG: tenantId = [TENANT_ID]
📱 DEBUG: tenantData = [TENANT_DATA]
```

### Supabase Console'da Test Et

```sql
-- Kullanıcı var mı?
SELECT * FROM users WHERE id = '[USER_ID]';

-- Tenant var mı?
SELECT * FROM tenants WHERE id = '[TENANT_ID]';

-- RPC fonksiyonu çalışıyor mu?
SELECT * FROM get_user_data_by_id('[USER_ID]');
```

---

## 📚 Referanslar

- **Supabase Docs**: https://supabase.com/docs
- **PostgreSQL RLS**: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- **Supabase RLS**: https://supabase.com/docs/guides/auth/row-level-security

---

## 🆕 Depo Transfer Modülü Tasarımı

### 1. Tablolar

| Tablo | Amaç | Kritik Alanlar |
|-------|------|----------------|
| `depot_notices` | Eksik/fazla duyurusu | id (uuid), tenant_id, branch_id, created_by, product_name, quantity, unit, type (enum), status (enum), note, expires_at, created_at, updated_at |
| `depot_notice_offers` | Şubeler arası teklif | id, notice_id, tenant_id, branch_id, offered_by, quantity, status (enum), decision_by, decision_at, message, created_at |

Opsiyonel ekler: `depot_notice_events` (tarihçe), `depot_notice_files` (fotoğraf), `depot_notice_matches` (otomatik eşleşme).

### 2. ENUM Taslakları

```sql
CREATE TYPE depot_notice_type AS ENUM ('shortage', 'surplus');
CREATE TYPE depot_notice_status AS ENUM ('open', 'in_transfer', 'fulfilled', 'cancelled');
CREATE TYPE depot_offer_status AS ENUM ('pending', 'accepted', 'rejected', 'expired');
```

### 3. Index / Constraint Önerileri

- `CREATE INDEX ON depot_notices (tenant_id, branch_id, status);`
- `CREATE INDEX ON depot_notice_offers (notice_id, status);`
- Aynı şubenin aynı notice için tek bekleyen teklifi: `UNIQUE (notice_id, branch_id) WHERE status = 'pending';`

### 4. RLS Politikaları

**depot_notices**
- SELECT: `tenant_id = current_tenant_id()`.
- INSERT: `tenant_id = current_tenant_id()` VE `branch_id = auth_branch_id()`.
- UPDATE/DELETE: `created_by = auth.uid()` VEYA rol `IN ('sube_muduru','firma_admin','grand_admin')`.

**depot_notice_offers**
- SELECT: `tenant_id = current_tenant_id()` VE (`branch_id = auth_branch_id()` OR notice owner).
- INSERT: `tenant_id = current_tenant_id()` + notice tenant kontrolü.
- UPDATE: yalnız notice sahibi `EXISTS (SELECT 1 FROM depot_notices n WHERE n.id = notice_id AND n.created_by = auth.uid())`.

### 5. Trigger/Fonksiyonlar

- `set_tenant_id()` → branch üzerinden tenant auto-fill.
- `update_updated_at_column()` → notice güncelleme.
- `close_notice_expire_pending_offers()` → notice kapanınca bekleyen teklifleri `expired` yap.
- Realtime notification (opsiyon): `NOTIFY depot_offer_events`.

### 6. API & Flutter Eşleşmesi

| İşlem | Supabase Çağrısı | Not |
|-------|------------------|-----|
| Listeleme | `.from('depot_notices').select('*, offers:depot_notice_offers(*)')` | Tenant/branch filtreli |
| Notice ekle | `.insert({...})` | Formdaki alanlar |
| Teklif gönder | `.from('depot_notice_offers').insert({...})` | Şube bazlı |
| Teklif onay/red | `.update({ status: 'accepted' | 'rejected', decision_by, decision_at }).eq('id', offerId)` | RLS owner kontrolü |
| Sayaç | View: `depot_notice_offer_counts` (pending, accepted) | AppBar badge |

### 7. Migration Adımları

1. Enum tiplerini oluştur.
2. `depot_notices` tablosu + trigger.
3. `depot_notice_offers` tablosu + unique + trigger.
4. RLS enable + policy setleri.
5. İçgörü view/RPC (örn. `my_depot_notice_summary`).
6. Demo seed (gerekirse).

### 8. Flutter Data Layer Adımları

1. `DepotStockNotice` ve `NoticeOffer` modellerini Supabase kolonlarıyla hizala.
2. `DepotRepository` (fetch/create/respond) ve Riverpod provider’larını ekle.
3. UI’da `offers` ve `pendingCounts` alanlarını Supabase sonuçları ile doldur.
4. Realtime kanal (opsiyon) ile teklif güncellemelerini dinle.

---

**Son Güncelleme**: 2025-11-26

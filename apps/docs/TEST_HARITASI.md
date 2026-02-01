# Yotech Uygulama Test Haritası

## Genel Bilgiler

### Roller ve Hiyerarşi
| Rol | Açıklama | Platform |
|-----|----------|----------|
| `grand_admin` | Sistem yöneticisi - tüm firmaları yönetir | Web Panel |
| `firma_admin` | Firma yöneticisi - kendi firmasını yönetir | Web Panel |
| `bolge_muduru` | Bölge müdürü - bölgesindeki şubeleri yönetir | Web Panel + Mobil |
| `sube_muduru` | Şube müdürü - kendi şubesini yönetir | Web Panel + Mobil |
| `personel` | Şube personeli | Mobil |

### Test Ortamı Hazırlığı
- [ ] Supabase veritabanı erişilebilir
- [ ] Web panel: `npm run dev` çalışıyor (localhost:3000)
- [ ] Mobil: `flutter run` çalışıyor
- [ ] Her rol için test kullanıcısı hazır

---

## BÖLÜM 1: KİMLİK DOĞRULAMA (AUTH)

### 1.1 Web Panel Giriş
| Test | Adımlar | Beklenen Sonuç | ✓ |
|------|---------|----------------|---|
| Başarılı giriş | E-posta ve şifre gir → Giriş Yap | Dashboard'a yönlendir | ☐ |
| Hatalı şifre | Yanlış şifre gir → Giriş Yap | Hata mesajı göster | ☐ |
| Boş form | Boş form gönder | Validasyon hatası | ☐ |
| Oturum devamı | Sayfa yenile | Oturum korunur | ☐ |
| Çıkış yap | "Çıkış Yap" butonuna tıkla | Login sayfasına yönlendir | ☐ |

### 1.2 Mobil Giriş
| Test | Adımlar | Beklenen Sonuç | ✓ |
|------|---------|----------------|---|
| Başarılı giriş | E-posta ve şifre gir → Giriş | Ana sayfaya yönlendir | ☐ |
| Hatalı şifre | Yanlış şifre gir | Hata mesajı göster | ☐ |
| Şifremi unuttum | Link'e tıkla | E-posta gönder ekranı | ☐ |
| Oturum devamı | Uygulamayı kapat/aç | Oturum korunur | ☐ |
| Çıkış yap | Ayarlar → Çıkış Yap | Login ekranına dön | ☐ |

---

## BÖLÜM 2: ROL BAZLI ERİŞİM TESTLERİ

### 2.1 Grand Admin (Web Panel)
| Menü | Sayfa | Test | Beklenen | ✓ |
|------|-------|------|----------|---|
| Genel Bakış | /overview | Sayfayı aç | Dashboard görünür | ☐ |
| Firmalar | /tenants | Sayfayı aç | Firma listesi | ☐ |
| Firmalar | /tenants | Yeni firma ekle | Firma oluşturulur | ☐ |
| Kullanıcı Yetkileri | /users | Sayfayı aç | Kullanıcı listesi | ☐ |
| Kullanıcı Yetkileri | /users | Kullanıcı düzenle | Rol değiştirilebilir | ☐ |
| Operasyon | /operations | Sayfayı aç | İşlem logları | ☐ |
| Formlar | /forms | Sayfayı aç | Form listesi | ☐ |
| Supabase | /supabase | Sayfayı aç | Supabase yönetimi | ☐ |
| Gözlemlenebilirlik | /observability | Sayfayı aç | Metrikler | ☐ |
| Ayarlar | /settings | Sayfayı aç | Ayarlar paneli | ☐ |

### 2.2 Firma Admin (Web Panel)
| Menü | Sayfa | Test | Beklenen | ✓ |
|------|-------|------|----------|---|
| Genel Bakış | /overview | Sayfayı aç | Firma dashboard'u | ☐ |
| Duyurular & Anketler | /announcements | Sayfayı aç | Duyuru listesi | ☐ |
| Duyurular & Anketler | /announcements | Yeni duyuru oluştur | Duyuru yayınlanır | ☐ |
| Kullanıcılar | /users | Sayfayı aç | Firma kullanıcıları | ☐ |
| Ürünler | /products | Sayfayı aç | Ürün listesi | ☐ |
| Ürünler | /products | Ürün ara | Arama çalışır | ☐ |
| Formlar | /forms | Sayfayı aç | Form şablonları | ☐ |
| Ayarlar | /settings | Sayfayı aç | Firma ayarları | ☐ |

### 2.3 Bölge Müdürü (Web Panel)
| Menü | Sayfa | Test | Beklenen | ✓ |
|------|-------|------|----------|---|
| Genel Bakış | /overview | Sayfayı aç | Bölge özeti | ☐ |
| Duyurular & Anketler | /announcements | Sayfayı aç | Duyurular | ☐ |
| Görevler | /tasks | Sayfayı aç | Görev listesi | ☐ |
| Görevler | /tasks | Yeni görev oluştur | Görev atanır | ☐ |
| **Mola Takibi** | /breaks | Sayfayı aç | Molalarım tab'ı | ☐ |
| **Mola Takibi** | /breaks | Ekip Molaları tab'ı | Şube seçici görünür | ☐ |
| **Mola Takibi** | /breaks | Şube filtrele | Sadece o şubenin molaları | ☐ |
| SKT Kontrol | /skt | Sayfayı aç | SKT listesi | ☐ |
| Ürün Listesi | /products | Sayfayı aç | Ürünler | ☐ |
| Personel | /personnel | Sayfayı aç | Bölge personeli | ☐ |
| Personel | /personnel | Personel ekle | Yeni personel | ☐ |
| Depolar Arası Sevk | /transfers | Sayfayı aç | Transfer listesi | ☐ |
| Mörş | /merch | Sayfayı aç | Mörş verileri | ☐ |
| Form Kontrol | /forms | Sayfayı aç | Formlar | ☐ |
| Ayarlar | /settings | Sayfayı aç | Ayarlar | ☐ |

### 2.4 Şube Müdürü (Web Panel)
| Menü | Sayfa | Test | Beklenen | ✓ |
|------|-------|------|----------|---|
| Genel Bakış | /overview | Sayfayı aç | Şube özeti | ☐ |
| Duyurular & Anketler | /announcements | Sayfayı aç | Duyurular | ☐ |
| Vardiya | /shifts | Sayfayı aç | Vardiya planı | ☐ |
| **Mola Takibi** | /breaks | Sayfayı aç | Molalarım | ☐ |
| **Mola Takibi** | /breaks | Ekip Molaları | Personel molaları (şube seçici yok) | ☐ |
| Görev | /tasks | Sayfayı aç | Görevler | ☐ |
| SKT Kontrol | /skt | Sayfayı aç | SKT listesi | ☐ |
| Ürün Listesi | /products | Sayfayı aç | Ürünler | ☐ |
| Personel | /personnel | Sayfayı aç | Şube personeli | ☐ |
| Form Kontrol | /forms | Sayfayı aç | Formlar | ☐ |
| Depolar Arası Sevk | /transfers | Sayfayı aç | Transferler | ☐ |
| Mörş | /merch | Sayfayı aç | Mörş | ☐ |
| Ayarlar | /settings | Sayfayı aç | Ayarlar | ☐ |

### 2.5 Bölge Müdürü (Mobil)
| Özellik | Ekran | Test | Beklenen | ✓ |
|---------|-------|------|----------|---|
| Ana Sayfa | HomeShell | Uygulamayı aç | Şube seçici + modüller | ☐ |
| Şube Seçimi | HomeShell | Farklı şube seç | Veriler güncellenir | ☐ |
| SKT | SktListPage | SKT modülünü aç | Taranan ürünler | ☐ |
| Görevler | BranchTasksPage | Görevleri görüntüle | Şube görevleri | ☐ |
| Mörş | MerchScreen | Mörş modülünü aç | Mörş verileri | ☐ |
| Duyurular | AnnouncementsPage | Duyuruları görüntüle | Duyuru listesi | ☐ |
| Formlar | FormsHubPage | Formları görüntüle | Form listesi | ☐ |
| Talepler | RequestsHubPage | Talepleri görüntüle | Talep listesi | ☐ |
| **Vardiya/Mola** | ShiftsAndBreaksPage | Açık sayfayı | Tab'lar görünür | ☐ |
| **Molalarım** | ShiftsAndBreaksPage | Molalarım tab'ı | Kendi molaları | ☐ |
| **Ekip Molaları** | ShiftsAndBreaksPage | Ekip tab'ı | Şube personeli molaları | ☐ |
| Ayarlar | SettingsPage | Ayarları aç | Profil & çıkış | ☐ |

### 2.6 Şube Müdürü (Mobil)
| Özellik | Test | Beklenen | ✓ |
|---------|------|----------|---|
| Ana Sayfa | Uygulamayı aç | Tek şube (kendi şubesi) | ☐ |
| Mola Başlat | Mola butonuna tıkla | Mola başlar, timer görünür | ☐ |
| Mola Bitir | Mola bitir butonuna tıkla | Mola biter, süre kaydedilir | ☐ |
| Ekip Molaları | Ekip tab'ına tıkla | Personel molaları görünür | ☐ |
| Görevler | Görevler modülü | Atanan görevler | ☐ |
| Görev Tamamla | Görev detay → Tamamla | Görev tamamlanır | ☐ |

### 2.7 Personel (Mobil)
| Özellik | Test | Beklenen | ✓ |
|---------|------|----------|---|
| Ana Sayfa | Uygulamayı aç | Kendi şubesi görünür | ☐ |
| Mola Başlat | Mola butonuna tıkla | Mola başlar | ☐ |
| Mola Bitir | Mola bitir | Mola biter | ☐ |
| Molalarım | Vardiya sayfası | Sadece kendi molaları | ☐ |
| Ekip Molaları | Tab'a tıkla | Erişim engellenir / gizli | ☐ |
| Görevler | Görevler modülü | Sadece atanan görevler | ☐ |
| Duyurular | Duyurular | Okunabilir | ☐ |

---

## BÖLÜM 3: MODÜL TESTLERİ

### 3.1 Mola Takibi (Break Tracking)

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Kendi molaları | Tüm roller | Molalarım tab'ı | Mola geçmişi görünür | ☐ |
| Tarih değiştir | Tüm roller | < > butonları | Farklı günler | ☐ |
| Ekip molaları - şube müdürü | sube_muduru | Ekip Molaları tab'ı | Personel molaları, şube seçici YOK | ☐ |
| Ekip molaları - bölge müdürü | bolge_muduru | Ekip Molaları tab'ı | Şube seçici görünür | ☐ |
| Şube filtreleme | bolge_muduru | Dropdown'dan şube seç | Sadece o şubenin molaları | ☐ |
| Tüm şubeler | bolge_muduru | "Tüm Şubeler" seç | Bölgedeki tüm molalar | ☐ |
| Aktif mola gösterimi | Tüm roller | Aktif mola varken | "Molada" badge'i | ☐ |

#### Mobil
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Mola başlat | Tüm roller | Ana sayfa → Mola başlat | Timer başlar | ☐ |
| Mola bitir | Tüm roller | Mola bitir | Süre kaydedilir | ☐ |
| Mola geçmişi | Tüm roller | Vardiya sayfası → Molalarım | Geçmiş görünür | ☐ |
| Günlük özet | Tüm roller | Molalarım | Toplam süre hesaplanır | ☐ |
| Ekip molaları | sube_muduru | Ekip Molaları tab'ı | Personel listesi | ☐ |
| Erişim kontrolü | personel | Ekip Molaları | Erişim yok / gizli | ☐ |

### 3.2 Görevler (Tasks)

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Görev listesi | bolge_muduru | Görevler sayfası | Liste görünür | ☐ |
| Görev oluştur | bolge_muduru | + Yeni Görev | Form açılır | ☐ |
| Görev atama | bolge_muduru | Şube/personel seç | Atama yapılır | ☐ |
| Görev detay | Tüm | Göreve tıkla | Detay sayfası | ☐ |
| Durum güncelle | Tüm | Durum değiştir | Kaydedilir | ☐ |

#### Mobil
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Görev listesi | Tüm | Görevler modülü | Atanan görevler | ☐ |
| Görev detay | Tüm | Göreve dokun | Detay ekranı | ☐ |
| Alt görev | Tüm | Alt görev tamamla | Checkbox güncellenir | ☐ |
| Görev tamamla | Tüm | Tamamla butonu | Durum güncellenir | ☐ |
| Görev oluştur | sube_muduru+ | + butonu | Görev formu | ☐ |
| Görev ilet | sube_muduru+ | İlet butonu | Başka şubeye ilet | ☐ |

### 3.3 SKT Kontrol

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| SKT listesi | Tüm | SKT Kontrol sayfası | Taranan ürünler | ☐ |
| Filtreleme | Tüm | Tarih/şube filtrele | Sonuçlar güncellenir | ☐ |
| Detay görüntüle | Tüm | Kayda tıkla | Ürün detayları | ☐ |

#### Mobil
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| SKT modülü | Tüm | SKT'ye dokun | SKT listesi | ☐ |
| Barkod tara | Tüm | Tarama başlat | Kamera açılır | ☐ |
| Ürün bul | Tüm | Barkod tarat | Ürün bulunur | ☐ |
| SKT kaydet | Tüm | Son kullanma tarihi gir | Kaydedilir | ☐ |
| Liste görüntüle | Tüm | SKT listesi | Taranan ürünler | ☐ |

### 3.4 Depolar Arası Sevk (Transfers)

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Transfer listesi | bolge_muduru+ | Transferler sayfası | Transfer listesi | ☐ |
| Transfer detay | bolge_muduru+ | Transfere tıkla | Ürün listesi | ☐ |
| Durum takibi | bolge_muduru+ | Durumu kontrol et | Güncel durum | ☐ |

#### Mobil
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Depo modülü | sube_muduru+ | Depo'ya dokun | Transfer listesi | ☐ |
| Yeni transfer | sube_muduru | + butonu | Transfer formu | ☐ |
| Ürün ekle | sube_muduru | Barkod tara | Ürün eklenir | ☐ |
| Transfer gönder | sube_muduru | Gönder | Transfer oluşturulur | ☐ |
| Gelen transfer | sube_muduru | Gelen transferler | Onay bekleyenler | ☐ |
| Transfer kabul | sube_muduru | Kabul et | Stok güncellenir | ☐ |

### 3.5 Mörş (Merchandising)

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Mörş listesi | bolge_muduru+ | Mörş sayfası | Kayıtlar | ☐ |
| Filtreleme | bolge_muduru+ | Şube/tarih filtrele | Sonuçlar | ☐ |

#### Mobil
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Mörş modülü | Tüm | Mörş'e dokun | Mörş listesi | ☐ |
| Yeni kayıt | Tüm | + butonu | Kayıt formu | ☐ |
| Fotoğraf çek | Tüm | Kamera | Fotoğraf eklenir | ☐ |
| Kaydet | Tüm | Kaydet | Mörş kaydedilir | ☐ |

### 3.6 Duyurular & Anketler

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Duyuru listesi | firma_admin+ | Duyurular sayfası | Duyuru listesi | ☐ |
| Yeni duyuru | firma_admin+ | + Yeni Duyuru | Duyuru formu | ☐ |
| Hedef seçimi | firma_admin+ | Şube/bölge seç | Hedef belirlenir | ☐ |
| Duyuru yayınla | firma_admin+ | Yayınla | Duyuru gönderilir | ☐ |
| Anket oluştur | firma_admin+ | Anket tipi seç | Anket formu | ☐ |
| Sonuçlar | firma_admin+ | Sonuçlara tıkla | Anket sonuçları | ☐ |

#### Mobil
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Duyurular | Tüm | Duyurular modülü | Duyuru listesi | ☐ |
| Duyuru oku | Tüm | Duyuruya dokun | İçerik görünür | ☐ |
| Anket cevapla | Tüm | Anket seç | Sorular görünür | ☐ |
| Anket gönder | Tüm | Cevapla & Gönder | Kaydedilir | ☐ |

### 3.7 Formlar

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Form listesi | Tüm | Formlar sayfası | Form şablonları | ☐ |
| Form oluştur | grand_admin | + Yeni Form | Form builder | ☐ |
| Sonuçlar | bolge_muduru+ | Sonuçlara tıkla | Doldurulmuş formlar | ☐ |

#### Mobil
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Formlar | Tüm | Formlar modülü | Atanan formlar | ☐ |
| Form doldur | Tüm | Forma dokun | Sorular görünür | ☐ |
| Form gönder | Tüm | Gönder | Kaydedilir | ☐ |

### 3.8 Personel Yönetimi

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Personel listesi | sube_muduru+ | Personel sayfası | Personel listesi | ☐ |
| Personel ekle | bolge_muduru+ | + Yeni Personel | Ekleme formu | ☐ |
| Personel düzenle | bolge_muduru+ | Düzenle | Düzenleme formu | ☐ |
| Personel sil | bolge_muduru+ | Sil | Silme onayı | ☐ |
| Şube filtresi | bolge_muduru | Şube seç | Sadece o şube | ☐ |

### 3.9 Ürün Listesi

#### Web Panel
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Ürün listesi | Tüm | Ürünler sayfası | Ürün tablosu | ☐ |
| Arama | Tüm | Arama kutusuna yaz | Filtreleme | ☐ |
| Sayfalama | Tüm | Sonraki sayfa | Sayfa değişir | ☐ |
| Sayfa başına kayıt | Tüm | Dropdown değiştir | Kayıt sayısı değişir | ☐ |

### 3.10 Talepler (Mobil)
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Talepler modülü | Tüm | Talepler'e dokun | Talep kategorileri | ☐ |
| İzin talebi | Tüm | İzin Talebi seç | İzin formu | ☐ |
| IT destek | Tüm | IT Destek seç | Destek formu | ☐ |
| Talep gönder | Tüm | Formu doldur & Gönder | Kaydedilir | ☐ |
| Talep takibi | Tüm | Taleplerim | Talep durumları | ☐ |

---

## BÖLÜM 4: ÇAPRAZ ROL TESTLERİ

### 4.1 Hiyerarşik Erişim
| Test | Açıklama | Beklenen | ✓ |
|------|----------|----------|---|
| Bölge müdürü → Şube verileri | Bölge müdürü başka bölgenin şubesine erişmeye çalışır | Erişim engellenir | ☐ |
| Şube müdürü → Başka şube | Şube müdürü başka şubenin verilerine erişmeye çalışır | Erişim engellenir | ☐ |
| Personel → Ekip molaları | Personel ekip molalarını görmeye çalışır | Erişim yok | ☐ |
| Personel → Personel yönetimi | Personel, personel sayfasına erişmeye çalışır | Erişim yok | ☐ |

### 4.2 Veri Tutarlılığı
| Test | Web Panel | Mobil | Beklenen | ✓ |
|------|-----------|-------|----------|---|
| Mola senkronizasyonu | - | Mola başlat | Her ikisinde görünür | ☐ |
| Görev güncelleme | Görev durumu değiştir | - | Mobilde güncellenir | ☐ |
| Duyuru | Duyuru yayınla | - | Mobilde görünür | ☐ |
| Personel ekleme | Personel ekle | - | Mobilde görünür | ☐ |

---

## BÖLÜM 5: PERFORMANS VE HATA DURUMLARI

### 5.1 Ağ Hataları
| Test | Adımlar | Beklenen | ✓ |
|------|---------|----------|---|
| Offline mod (Mobil) | İnterneti kapat | Hata mesajı, retry butonu | ☐ |
| API timeout | Yavaş ağ simüle et | Yükleniyor göstergesi, timeout mesajı | ☐ |
| Bağlantı geri gelme | İnterneti aç | Otomatik yenileme | ☐ |

### 5.2 Boş Durumlar
| Test | Koşul | Beklenen | ✓ |
|------|-------|----------|---|
| Mola yok | O gün mola yokken | "Mola kaydı yok" mesajı | ☐ |
| Görev yok | Atanan görev yokken | "Görev yok" mesajı | ☐ |
| Personel yok | Şubede personel yokken | Boş liste mesajı | ☐ |

### 5.3 Sayfalama / Büyük Veri
| Test | Adımlar | Beklenen | ✓ |
|------|---------|----------|---|
| 1000+ ürün | Ürün listesini aç | Sayfalama çalışır, donma yok | ☐ |
| Scroll performansı | Listeyi hızlı kaydır | Akıcı scroll | ☐ |

---

## BÖLÜM 6: BİLDİRİMLER

### 6.1 Push Bildirimleri (Mobil)
| Test | Koşul | Beklenen | ✓ |
|------|-------|----------|---|
| Bildirim izni | İlk açılışta | İzin dialogu göster | ☐ |
| Yeni görev bildirimi | Görev atandığında | Push bildirim gelir | ☐ |
| Duyuru bildirimi | Duyuru yayınlandığında | Push bildirim gelir | ☐ |
| Bildirime tıklama | Bildirime tıkla | İlgili sayfaya git | ☐ |

---

## BÖLÜM 7: AYARLAR

### 7.1 Web Panel Ayarlar
| Test | Rol | Adımlar | Beklenen | ✓ |
|------|-----|---------|----------|---|
| Profil görüntüle | Tüm | Ayarlar sayfası | Profil bilgileri | ☐ |
| Şifre değiştir | Tüm | Şifre değiştir | Şifre güncellenir | ☐ |

### 7.2 Mobil Ayarlar
| Test | Adımlar | Beklenen | ✓ |
|------|---------|----------|---|
| Profil görüntüle | Ayarlar → Profil | Kullanıcı bilgileri | ☐ |
| Bildirim ayarları | Ayarlar → Bildirimler | Toggle'lar çalışır | ☐ |
| Çıkış yap | Ayarlar → Çıkış | Login ekranına dön | ☐ |
| Uygulama versiyonu | Ayarlar | Versiyon görünür | ☐ |

---

## TEST SONUÇ ÖZETİ

| Bölüm | Toplam Test | Geçen | Kalan | Başarı % |
|-------|-------------|-------|-------|----------|
| Kimlik Doğrulama | | | | |
| Rol Bazlı Erişim | | | | |
| Modüller | | | | |
| Çapraz Rol | | | | |
| Performans/Hata | | | | |
| Bildirimler | | | | |
| Ayarlar | | | | |
| **TOPLAM** | | | | |

---

## NOTLAR

### Bulunan Hatalar
| # | Tarih | Açıklama | Önem | Durum |
|---|-------|----------|------|-------|
| 1 | | | | |
| 2 | | | | |

### İyileştirme Önerileri
| # | Açıklama | Öncelik |
|---|----------|---------|
| 1 | | |
| 2 | | |

---

## TEST KULLANICILARI

| Rol | E-posta | Şifre | Firma/Şube |
|-----|---------|-------|------------|
| grand_admin | | | - |
| firma_admin | | | |
| bolge_muduru | | | |
| sube_muduru | | | |
| personel | | | |

---

*Son Güncelleme: 30 Ocak 2026*

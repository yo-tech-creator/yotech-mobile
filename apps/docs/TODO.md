# Çalışma Notları

## Yapıldı
- Supabase kimlik doğrulama akışı (web): `getSession` uyarıları giderildi; middleware ve dashboard guard'ları `getUser` ile doğruluyor, hata durumunda auth çerezleri temizleniyor.
- Kullanıcı dizini API'leri (web): `tenants`, `users`, `branches`, `tasks/assignees` uçları `getUser` ile yetkilendiriyor; rol kontrolleri korunuyor.
- UI düzenlemeleri (web): Kullanıcı tablosu ve ürün listesinde kolon genişlikleri ve sayfalama barı kompakt hale getirildi; buton/picker boyutları hizalandı.
- Ürün listesi (web, şube müdürü): Sayfa başına kayıt seçimi, çift taraflı sayfalama, gösterilen/toplam sayacı eklendi.
- Auth guard (web): Tenants sayfasında grand_admin zorunluluğu ve profil hatası yönlendirmesi.
- Mobile başlatma: `.env` zorunlu SUPABASE_URL/ANON_KEY doğrulanıyor; Firebase & Supabase initialize; SharedPreferences Riverpod ile enjekte ediliyor; app theme/light color scheme ayarlandı.
- Mobile yönlendirme: AppRouter, auth state’e göre grand_admin → panel, bolge_muduru → dashboard, diğer roller → HomeShell; hata state'i için retry butonu var.

## Yapılacak
- Supabase uyarıları: Web panelde kalan `getSession`/`onAuthStateChange` kullanımlarını tarayıp `getUser` ile değiştir; uyarı loglarını temizle.
- Web perf/UX: Büyük listeler (kullanıcılar/ürünler) için server-side pagination veya incremental fetch; tablo skeleton/loading durumlarını ekle.
- Hata yakalama (web): API route'larında 23505/permission denied gibi beklenen hatalar için anlamlı mesaj ve seviyeli loglama.
- Testler: Login, ürün listesi sayfalama, kullanıcı dizini CRUD ve auth guard senaryoları için smoke/E2E (Playwright) akışları ekle.
- Mobile push: FCM foreground bildirimi ve izin akışı kontrollerini doğrula; iOS notification channel ayarlarını gözden geçir.
- Mobile auth/provider: Supabase oturum yenileme hata senaryolarını kontrol et; ağ hatalarında kullanıcıya geri bildirim ekranı ekle.
- Mobile ürün/transfer modülleri: Env/rol bazlı kısıtların UI’da da yansıtıldığını doğrula; liste ekranlarında boş durum & hata gösterimleri ekle.

## Copilot Tavsiyesi
- Ortak `.env` şeması (zod/tüm platformlar) ile eksik/yanlış env’de fail-fast başlatma; CI’da doğrulama adımı ekle.
- Supabase service role anahtarını yalnızca server (web API) tarafında tut; istemcide sadece anon key kullanıldığından emin ol.
- Loglama: Web API’lerinde pino benzeri yapı; hata/uyarı/info ayrımı ve request id koruması.
- Önbellek/yenileme: Lookup verileri (rol listesi, şube listesi) için cache + `revalidateTag`; gereksiz sorguları azalt.
- UI tutarlılığı: Tüm tablolar için ortak pagination/search bileşeni çıkar; mobile & web’de aynı metrikleri gösteren status bar ekle.
- Test otomasyonu: Critik akışlar için kısa Playwright senaryoları ve mobile widget/integration testleri ekle; FCM/Supabase için mocking stratejisi belirle.

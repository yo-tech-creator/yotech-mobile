# Depot Transfer Flutter Entegrasyon Planı

## 1. Veri Modelleri
- `DepotStockNotice` modeli Supabase kolonları ile hizalanacak: `tenantId`, `branchId`, `createdBy`, `status`, `expiresAt`, `offers`.
- `NoticeOffer` modeli `decisionBy`, `decisionAt`, `message`, `status` alanları ile genişletilecek.
- JSON ↔️ Dart dönüşümü için `fromJson` / `toJson` yardımcıları eklenecek.

## 2. Data Source / Repository
1. **SupabaseClient wrapper** (`lib/core/data/supabase_client.dart`) mevcut ise oradan reuse.
2. Yeni `DepotTransferRemoteDataSource`:
   - `Future<List<DepotStockNotice>> fetchNotices({DepotNoticeFilter filter})`
   - `Future<DepotStockNotice> createNotice(CreateNoticePayload payload)`
   - `Future<void> respondOffer({required String offerId, required NoticeOfferStatus status})`
   - `Future<void> createOffer(CreateOfferPayload payload)`
   - `Stream<DepotStockNotice> subscribeNotice(String noticeId)` (opsiyonel realtime)
3. `DepotTransferRepository` arayüzü yukarıdaki metodları soyutlayacak. Mock/fixture desteği için `DepotTransferRepositoryImpl` + `DepotTransferRepositoryFake`.

## 3. Riverpod Katmanı
- `depotNoticesProvider = FutureProvider.autoDispose` → Supabase sorgusunu tetikler.
- `myDepotNoticeBadgeProvider = Provider<int>` → `depot_notice_offer_counts` view'ından pending sayısını hesaplar.
- `createDepotNoticeController` (`AsyncNotifier`) → form submit durumunu yönetir.
- `respondOfferController` → Accept/Reject UI butonunu bağlar.

## 4. UI Entegrasyonu
1. `DepotPage` `ref.watch(depotNoticesProvider)` ile veri çekecek, local fake fallback dev modda.
2. AppBar’daki rozet `myDepotNoticeBadgeProvider` değerini kullanacak.
3. `_OfferInboxSheet` içinde `respondOfferController` kullanılarak Supabase update çağrısı yapılacak.
4. Yeni notice oluşturma formu `createDepotNoticeController` aracılığıyla repository’e `createNotice` çağrısı yapacak; başarılı olunca provider invalidate.

## 5. Hata Yönetimi & Cache
- Supabase hatalarını `AppFailure` modeline map et (`PostgrestException`, `AuthException`).
- Ağ çağrıları için `retry`/`timeout` wrapper'ı eklenebilir.
- `depotNoticesProvider` için `keepAlive` + manual refresh (pull-to-refresh) desteği.

## 6. Yol Haritası
1. Repository & datasource sınıflarını oluştur, testler ekle (`test/core/depot_transfer_remote_data_source_test.dart`).
2. Riverpod provider’larını tanımla, UI ile entegre et.
3. Realtime gereksinimi netleşirse `supabase.channel('depot_notice_offers')` aboneliği ekle.
4. Son aşamada Supabase policy testleri için `supabase/tests` betikleri hazırlanacak.

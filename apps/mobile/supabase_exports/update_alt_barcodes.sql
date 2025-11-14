-- Her urune farkli alternatif barkodlar atamak icin guncelleme betigi.
-- Bunu Supabase SQL editorunde veya ayni veritabanina bagli bir psql oturumunda calistirin.
-- Bu sorgu mevcut alt_barcodes dizisini her urunun UUID degerinden uretilen iki deterministik ve benzersiz
-- sayisal degerle degistirir. Sadece belirli urunleri guncellemek isterseniz son UPDATE deyimine WHERE kosulu ekleyin.

WITH generated AS (
    SELECT
        id,
    -- md5 hex cikisini rakamlara cevirerek alt barkodun sayisal kalmasini sagla.
        translate(substring(md5(id || 'alt1'), 1, 13), 'abcdef', '123456') AS alt1,
        translate(substring(md5(id || 'alt2'), 1, 13), 'abcdef', '123456') AS alt2
    FROM products
    -- Sadece tek bir urun icin calistirmak isterseniz bu satiri asagidaki gibi degistirin:
    -- FROM products WHERE id = '0b9c4895-1932-419c-be0c-cdd807ea0825'::uuid
)
UPDATE products AS p
SET alt_barcodes = ARRAY[generated.alt1, generated.alt2]
FROM generated
WHERE p.id = generated.id;

-- Opsiyonel: guncellemeyi dogrulayin ve duplikeleri kontrol edin.
-- SELECT id, name, alt_barcodes, barcode FROM products ORDER BY name;
-- SELECT barcode, alt_barcodes FROM products WHERE alt_barcodes && ARRAY[barcode];

-- Belirli bir urune manuel barkod atamak isterseniz asagidaki ornegi kullanin:
-- WITH manuel AS (
--     SELECT '0b9c4895-1932-419c-be0c-cdd807ea0825'::uuid AS id,
--            ARRAY['1234567890123', '9876543210987']         AS yeni_alt_barkodlar
-- )
-- UPDATE products p
-- SET alt_barcodes = manuel.yeni_alt_barkodlar
-- FROM manuel
-- WHERE p.id = manuel.id;

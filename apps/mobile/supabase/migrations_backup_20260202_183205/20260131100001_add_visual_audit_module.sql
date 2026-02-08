-- Görsel Denetim modülünü modules tablosuna ekle
INSERT INTO modules (code, name, description, icon, active, display_order)
VALUES (
  'visual_audit',
  'Görsel Denetim',
  'Günlük rutin bölüm fotoğrafları takip sistemi. Personel belirlenen saatlerde bölüm fotoğrafları yükler, yöneticiler takip eder.',
  'camera_alt',
  true,
  15
)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon;

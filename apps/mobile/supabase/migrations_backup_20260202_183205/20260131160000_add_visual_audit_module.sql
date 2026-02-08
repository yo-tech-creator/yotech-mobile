-- Visual Audit modülünü modules tablosuna ekle
-- Bu sayede mobilde bottom bar'da görünecek

-- Önce modülü ekle (yoksa)
INSERT INTO modules (code, name, icon, description, active, is_core)
VALUES (
  'visual_audit',
  'Görsel Denetim',
  'camera',
  'Günlük rutin bölüm fotoğrafları takip ve onay sistemi',
  true,
  false
)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  icon = EXCLUDED.icon,
  description = EXCLUDED.description,
  active = true;

-- Test tenant için modülü etkinleştir (varsa)
INSERT INTO tenant_modules (tenant_id, module_code, is_enabled)
SELECT t.id, 'visual_audit', true
FROM tenants t
WHERE NOT EXISTS (
  SELECT 1 FROM tenant_modules tm 
  WHERE tm.tenant_id = t.id AND tm.module_code = 'visual_audit'
)
ON CONFLICT (tenant_id, module_code) DO UPDATE SET is_enabled = true;

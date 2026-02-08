-- Mobilde kullanılmayan modülleri pasif yap veya sil
-- Kullanılan modüller: skt, forms, shifts, announcements, tasks, talep, puantaj, merchandising, profil, visual_audit

-- 1. Kullanılmayan modülleri pasif yap (active = false)
UPDATE public.modules SET active = false WHERE code IN (
    'stoksuz',        -- Stoksuz Ürünler - mobilde yok
    'takvim',         -- Takvim - mobilde yok
    'malfunctions',   -- Arıza Bildirimi - mobilde yok
    'payroll',        -- Bordro - mobilde yok
    'performance',    -- Performans - mobilde yok
    'transfers',      -- Transferler - interbranch_transfer olarak kullanılıyor
    'inventory_management' -- Envanter - farklı kullanılıyor
);

-- 2. Aktif kullanılan modüllerin aktif olduğundan emin ol
UPDATE public.modules SET active = true WHERE code IN (
    'skt',
    'form_management',
    'shift_management',
    'announcements',
    'task_management',
    'talep',
    'puantaj',
    'merchandising',
    'profil',
    'visual_audit'
);

-- 3. Eksik modülleri ekle (interbranch_transfer gibi)
INSERT INTO public.modules (code, name, description, icon, is_core, display_order, active)
VALUES 
    ('interbranch_transfer', 'Şubeler Arası Transfer', 'Şubeler arası ürün transferi', 'truck', false, 17, true),
    ('it_ticket', 'IT Talepleri', 'IT destek talepleri', 'monitor', false, 18, true),
    ('leave_request', 'İzin Talepleri', 'İzin ve mazeret talepleri', 'calendar-off', false, 19, true),
    ('instore_shortage', 'Mağaza İçi Eksiklik', 'Mağaza içi eksiklik bildirimi', 'alert-circle', false, 20, true),
    ('time_attendance', 'Puantaj', 'Giriş-çıkış puantaj takibi', 'fingerprint', false, 21, true)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    active = EXCLUDED.active;

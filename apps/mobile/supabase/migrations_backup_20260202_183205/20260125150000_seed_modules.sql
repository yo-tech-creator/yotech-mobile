-- Seed modules table with all available modules
-- This data was lost during db reset

INSERT INTO public.modules (code, name, description, icon, is_core, display_order, active)
VALUES 
    ('announcements', 'Duyurular', 'Duyuru ve anket yönetimi', 'megaphone', false, 1, true),
    ('form_management', 'Form Yönetimi', 'Form şablonları ve gönderimler', 'clipboard-list', false, 2, true),
    ('inventory_management', 'Envanter Yönetimi', 'Stok ve envanter takibi', 'package', false, 3, true),
    ('malfunctions', 'Arıza Bildirimi', 'Arıza raporları ve takibi', 'alert-triangle', false, 4, true),
    ('merchandising', 'Merchandising', 'Mağaza düzenleme ve sergileme', 'shopping-bag', false, 5, true),
    ('profil', 'Profil', 'Kullanıcı profil yönetimi', 'user', true, 6, true),
    ('puantaj', 'Puantaj', 'Çalışan puantaj ve devam takibi', 'clock', false, 7, true),
    ('shift_management', 'Vardiya Yönetimi', 'Vardiya planlama ve takibi', 'calendar-clock', false, 8, true),
    ('skt', 'SKT Takibi', 'Son kullanma tarihi takibi', 'calendar-x', false, 9, true),
    ('stoksuz', 'Stoksuz Ürünler', 'Stoksuz ürün bildirimi', 'package-x', false, 10, true),
    ('takvim', 'Takvim', 'Etkinlik ve toplantı takvimi', 'calendar', false, 11, true),
    ('talep', 'Talep Yönetimi', 'İzin ve talep yönetimi', 'file-text', false, 12, true),
    ('task_management', 'Görev Yönetimi', 'Görev atama ve takibi', 'check-square', false, 13, true),
    ('transfers', 'Transferler', 'Ürün transferleri', 'arrow-right-left', false, 14, true),
    ('performance', 'Performans', 'Performans değerlendirme', 'trending-up', false, 15, true),
    ('payroll', 'Bordro', 'Bordro ve ödeme yönetimi', 'wallet', false, 16, true)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    is_core = EXCLUDED.is_core,
    display_order = EXCLUDED.display_order,
    active = EXCLUDED.active;

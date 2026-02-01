-- Visual Audit RPC fonksiyonlarına GRANT yetkileri

-- get_my_visual_audit_tasks - personel ve yöneticiler için
GRANT EXECUTE ON FUNCTION get_my_visual_audit_tasks(DATE, TEXT) TO authenticated;

-- get_visual_audit_task_photos - herkes için
GRANT EXECUTE ON FUNCTION get_visual_audit_task_photos(UUID) TO authenticated;

-- get_visual_audit_comments - herkes için
GRANT EXECUTE ON FUNCTION get_visual_audit_comments(UUID) TO authenticated;

-- get_visual_audit_sections - herkes için
GRANT EXECUTE ON FUNCTION get_visual_audit_sections() TO authenticated;

-- upload_visual_audit_photo - personel için
GRANT EXECUTE ON FUNCTION upload_visual_audit_photo(UUID, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

-- add_visual_audit_comment - herkes için (comment_type visual_audit_comment_type enum kullanır)
GRANT EXECUTE ON FUNCTION add_visual_audit_comment(UUID, TEXT, visual_audit_comment_type, UUID) TO authenticated;

-- get_visual_audit_tasks_for_manager - yöneticiler için
GRANT EXECUTE ON FUNCTION get_visual_audit_tasks_for_manager(DATE, UUID, UUID, TEXT, INTEGER, INTEGER) TO authenticated;

-- get_visual_audit_stats - yöneticiler için
GRANT EXECUTE ON FUNCTION get_visual_audit_stats(DATE) TO authenticated;

-- create_visual_audit_section - yöneticiler için
GRANT EXECUTE ON FUNCTION create_visual_audit_section(TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- create_visual_audit_template - yöneticiler için
GRANT EXECUTE ON FUNCTION create_visual_audit_template(TEXT, UUID[], TEXT[], TEXT, UUID[], visual_audit_recurrence, INTEGER[], INTEGER[], INTEGER, INTEGER) TO authenticated;

-- get_visual_audit_templates_for_manager - yöneticiler için
GRANT EXECUTE ON FUNCTION get_visual_audit_templates_for_manager() TO authenticated;

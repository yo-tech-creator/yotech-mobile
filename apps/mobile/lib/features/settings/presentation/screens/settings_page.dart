import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Hesap',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Şifreyi değiştir'),
            subtitle: const Text('Mevcut şifrenizi güncelleyin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Bildirimler'),
            subtitle: const Text('Bildirim ayarlarını yönetin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Dil'),
            subtitle: const Text('Türkçe'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Tema'),
            subtitle: const Text('Sistem temasını kullan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Hakkında'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Yardım'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Gizlilik'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null || user.email == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Oturum bulunamadı. Lütfen tekrar giriş yapın.')),
        );
      }
      return;
    }

    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool isSubmitting = false;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Şifreyi değiştir'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Mevcut şifre',
                          suffixIcon: IconButton(
                            icon: Icon(showCurrent
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => showCurrent = !showCurrent),
                          ),
                        ),
                        obscureText: !showCurrent,
                        enabled: !isSubmitting,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Mevcut şifre gerekli';
                          }
                          if (v.length < 6) {
                            return 'En az 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Yeni şifre',
                          suffixIcon: IconButton(
                            icon: Icon(showNew
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(() => showNew = !showNew),
                          ),
                        ),
                        obscureText: !showNew,
                        enabled: !isSubmitting,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Yeni şifre gerekli';
                          }
                          if (v.length < 8) {
                            return 'En az 8 karakter';
                          }
                          final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
                          final hasNumber = RegExp(r'[0-9]').hasMatch(v);
                          if (!(hasLetter && hasNumber)) {
                            return 'Harf ve rakam içermeli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Yeni şifre (tekrar)',
                          suffixIcon: IconButton(
                            icon: Icon(showConfirm
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => showConfirm = !showConfirm),
                          ),
                        ),
                        obscureText: !showConfirm,
                        enabled: !isSubmitting,
                        validator: (v) {
                          if (v != newPasswordController.text) {
                            return 'Şifreler eşleşmiyor';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => isSubmitting = true);
                          try {
                            // Mevcut şifreyi doğrula
                            await client.auth.signInWithPassword(
                              email: user.email!,
                              password: currentPasswordController.text,
                            );

                            // Yeni şifreyi uygula
                            await client.auth.updateUser(
                              UserAttributes(
                                  password: newPasswordController.text),
                            );

                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Şifreniz güncellendi.')),
                              );
                            }
                          } on AuthException catch (e) {
                            if (!ctx.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          } catch (e) {
                            if (!ctx.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Bir hata oluştu. Lütfen tekrar deneyin.')),
                            );
                          } finally {
                            if (ctx.mounted) {
                              setState(() => isSubmitting = false);
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/announcements/data/repositories/announcements_repository.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';

/// Target scope options for announcements
enum TargetScope {
  myBranch('my_branch', 'Kendi Şubem'),
  myBranches('my_branches', 'Bölgemdeki Tüm Şubeler'),
  selectedBranches('selected_branches', 'Seçili Şubeler');

  const TargetScope(this.value, this.label);
  final String value;
  final String label;
}

class CreateAnnouncementPage extends ConsumerStatefulWidget {
  const CreateAnnouncementPage({super.key});

  @override
  ConsumerState<CreateAnnouncementPage> createState() =>
      _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState
    extends ConsumerState<CreateAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _summaryController = TextEditingController();

  bool _isLoading = false;
  bool _isPinned = false;
  bool _managersOnly = false;
  int _priority = 2;
  DateTime? _expiresAt;
  TargetScope _targetScope = TargetScope.myBranch;
  final List<String> _selectedBranchIds = [];
  List<Map<String, dynamic>> _availableBranches = [];
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndBranches();
  }

  Future<void> _loadUserRoleAndBranches() async {
    final authState = ref.read(authProvider);
    authState.whenOrNull(
      authenticated: (user) {
        setState(() {
          _userRole = user.role;
          // Şube müdürü için varsayılan scope kendi şubesi
          if (user.role == 'sube_muduru') {
            _targetScope = TargetScope.myBranch;
          } else if (user.role == 'bolge_muduru') {
            _targetScope = TargetScope.myBranches;
          }
        });
      },
    );

    try {
      final repo = ref.read(announcementsRepositoryProvider);
      final branches = await repo.getAvailableBranches();
      if (mounted) {
        setState(() {
          _availableBranches = branches;
        });
      }
    } catch (e) {
      debugPrint('Şubeler yüklenemedi: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  List<TargetScope> get _availableScopes {
    if (_userRole == 'sube_muduru') {
      return [TargetScope.myBranch];
    } else if (_userRole == 'bolge_muduru') {
      return [
        TargetScope.myBranches,
        TargetScope.selectedBranches,
      ];
    }
    return TargetScope.values;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(announcementsRepositoryProvider);

      List<String>? targetBranches;
      if (_targetScope == TargetScope.selectedBranches) {
        targetBranches = _selectedBranchIds;
      }

      await repo.createAnnouncement(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        summary: _summaryController.text.trim().isNotEmpty
            ? _summaryController.text.trim()
            : null,
        targetScope: _targetScope.value,
        targetBranches: targetBranches,
        managersOnly: _managersOnly,
        pinned: _isPinned,
        priority: _priority,
        expiresAt: _expiresAt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duyuru başarıyla oluşturuldu'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _expiresAt = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Duyuru'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Yayınla'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Başlık *',
                hintText: 'Duyuru başlığını girin',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Başlık zorunludur';
                }
                if (value.trim().length < 3) {
                  return 'Başlık en az 3 karakter olmalıdır';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Summary (optional)
            TextFormField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: 'Özet (opsiyonel)',
                hintText: 'Kısa bir özet girin',
                prefixIcon: Icon(Icons.short_text),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Content
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'İçerik *',
                hintText: 'Duyuru içeriğini girin',
                prefixIcon: Icon(Icons.article),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'İçerik zorunludur';
                }
                if (value.trim().length < 10) {
                  return 'İçerik en az 10 karakter olmalıdır';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Target Scope Section
            Text(
              'Hedef Kitle',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _availableScopes.map((scope) {
                  return RadioListTile<TargetScope>(
                    title: Text(scope.label),
                    subtitle: Text(_getScopeDescription(scope)),
                    value: scope,
                    groupValue: _targetScope,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _targetScope = value;
                          if (value != TargetScope.selectedBranches) {
                            _selectedBranchIds.clear();
                          }
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ),

            // Branch Selection (if selectedBranches)
            if (_targetScope == TargetScope.selectedBranches) ...[
              const SizedBox(height: 16),
              Text(
                'Şube Seçimi',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_availableBranches.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Yükleniyor...'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: _availableBranches.map((branch) {
                      final branchId = branch['id'] as String;
                      final branchName = branch['name'] as String? ?? '';
                      final branchCode = branch['code'] as String? ?? '';
                      final isSelected = _selectedBranchIds.contains(branchId);

                      return CheckboxListTile(
                        title: Text(branchName),
                        subtitle: Text(branchCode),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedBranchIds.add(branchId);
                            } else {
                              _selectedBranchIds.remove(branchId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
            const SizedBox(height: 24),

            // Options Section
            Text(
              'Seçenekler',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Sabitlenmiş'),
                    subtitle: const Text('Duyuru listenin başında görünür'),
                    value: _isPinned,
                    onChanged: (value) => setState(() => _isPinned = value),
                    secondary: Icon(
                      _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: _isPinned ? colorScheme.primary : null,
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Sadece Yöneticiler'),
                    subtitle: const Text('Sadece şube müdürleri görür'),
                    value: _managersOnly,
                    onChanged: (value) => setState(() => _managersOnly = value),
                    secondary: Icon(
                      Icons.admin_panel_settings,
                      color: _managersOnly ? colorScheme.primary : null,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.priority_high),
                    title: const Text('Öncelik'),
                    subtitle: Text(_getPriorityLabel(_priority)),
                    trailing: SizedBox(
                      width: 150,
                      child: Slider(
                        value: _priority.toDouble(),
                        min: 1,
                        max: 3,
                        divisions: 2,
                        label: _getPriorityLabel(_priority),
                        onChanged: (value) {
                          setState(() => _priority = value.round());
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('Son Geçerlilik Tarihi'),
                    subtitle: Text(
                      _expiresAt != null
                          ? '${_expiresAt!.day}.${_expiresAt!.month}.${_expiresAt!.year}'
                          : 'Süresiz',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_expiresAt != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _expiresAt = null),
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _selectExpiryDate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? 'Gönderiliyor...' : 'Duyuruyu Yayınla'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getScopeDescription(TargetScope scope) {
    switch (scope) {
      case TargetScope.myBranch:
        return 'Duyuru sadece kendi şubenizde görünür';
      case TargetScope.myBranches:
        return 'Duyuru bölgenizdeki tüm şubelerde görünür';
      case TargetScope.selectedBranches:
        return 'Duyuru seçtiğiniz şubelerde görünür';
    }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Düşük';
      case 2:
        return 'Normal';
      case 3:
        return 'Yüksek';
      default:
        return 'Normal';
    }
  }
}

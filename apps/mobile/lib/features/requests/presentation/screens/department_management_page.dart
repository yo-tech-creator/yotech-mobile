import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/shared.dart';
import '../../data/request_repository.dart';
import '../../domain/models/department.dart';

class DepartmentManagementPage extends ConsumerStatefulWidget {
  const DepartmentManagementPage({super.key});

  @override
  ConsumerState<DepartmentManagementPage> createState() =>
      _DepartmentManagementPageState();
}

class _DepartmentManagementPageState
    extends ConsumerState<DepartmentManagementPage> {
  Future<void> _refresh() {
    ref.invalidate(departmentManagementProvider);
    return ref.read(departmentManagementProvider.future);
  }

  Future<void> _showCreateDepartmentDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Departman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Departman Adı',
                hintText: 'Örn: Teknik Servis',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
                hintText: 'Departman hakkında kısa bilgi',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Departman adı boş olamaz')),
        );
        return;
      }

      try {
        final repo = ref.read(requestRepositoryProvider);
        await repo.createDepartment(
          name: name,
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Departman oluşturuldu')),
          );
          _refresh();
        }
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${e.message}')),
          );
        }
      }
    }
  }

  Future<void> _showEditDepartmentDialog(Department dept) async {
    final nameController = TextEditingController(text: dept.name);
    final descController = TextEditingController(text: dept.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Departmanı Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Departman Adı',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Departman adı boş olamaz')),
        );
        return;
      }

      try {
        final repo = ref.read(requestRepositoryProvider);
        await repo.updateDepartment(
          departmentId: dept.id,
          name: name,
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Departman güncellendi')),
          );
          _refresh();
        }
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${e.message}')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteDepartment(Department dept) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Departmanı Sil'),
        content: Text(
          '"${dept.name}" departmanını silmek istediğinizden emin misiniz?\n\n'
          'Bu işlem departmana atanmış personellerin atamasını kaldıracaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(requestRepositoryProvider);
        await repo.deleteDepartment(dept.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Departman silindi')),
          );
          _refresh();
        }
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${e.message}')),
          );
        }
      }
    }
  }

  void _showDepartmentDetails(Department dept) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DepartmentDetailPage(department: dept),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentManagementProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: departmentsAsync.when(
        data: (departments) {
          if (departments.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 40),
                const AppEmptyState(
                  icon: Icons.business_outlined,
                  title: 'Departman Yok',
                  subtitle:
                      'Henüz departman oluşturulmamış.\nYeni departman eklemek için + butonuna tıklayın.',
                ),
                const SizedBox(height: 24),
                Center(
                  child: FilledButton.icon(
                    onPressed: _showCreateDepartmentDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Departman Oluştur'),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: departments.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(Icons.business, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Departmanlar (${departments.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        onPressed: _showCreateDepartmentDialog,
                        icon: const Icon(Icons.add),
                        tooltip: 'Yeni Departman',
                      ),
                    ],
                  ),
                );
              }

              final dept = departments[index - 1];
              return _DepartmentCard(
                department: dept,
                onTap: () => _showDepartmentDetails(dept),
                onEdit: () => _showEditDepartmentDialog(dept),
                onDelete: () => _confirmDeleteDepartment(dept),
              );
            },
          );
        },
        loading: () => const Center(child: AppLoading()),
        error: (error, _) => Center(
          child: AppErrorState(
            title: 'Bir Hata Oluştu',
            message: 'Departmanlar yüklenirken sorun oluştu.\n$error',
          ),
        ),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Department department;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: colors.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (department.description != null &&
                        department.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        department.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: colors.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Personel atamak için dokunun',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colors.outline),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Düzenle'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Sil', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Departman detay sayfası - personel atama
class _DepartmentDetailPage extends ConsumerStatefulWidget {
  const _DepartmentDetailPage({required this.department});

  final Department department;

  @override
  ConsumerState<_DepartmentDetailPage> createState() =>
      _DepartmentDetailPageState();
}

class _DepartmentDetailPageState extends ConsumerState<_DepartmentDetailPage> {
  List<DepartmentUser> _assignedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedUsers();
  }

  Future<void> _loadAssignedUsers() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(requestRepositoryProvider);
      final users = await repo.getDepartmentUsers(widget.department.id);
      if (mounted) {
        setState(() {
          _assignedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _showAssignUserDialog() async {
    final allUsersAsync = ref.read(assignableUsersProvider);
    final allUsers = allUsersAsync.valueOrNull ?? [];

    // Zaten atanmış kullanıcıları filtrele
    final assignedIds = _assignedUsers.map((u) => u.id).toSet();
    final availableUsers =
        allUsers.where((u) => !assignedIds.contains(u.id)).toList();

    if (availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atanabilecek kullanıcı bulunamadı')),
      );
      return;
    }

    final selectedUser = await showModalBottomSheet<DepartmentUser>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.person_add_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Personel Seç',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: availableUsers.length,
                itemBuilder: (context, index) {
                  final user = availableUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(user.fullName),
                    subtitle: Text(user.roleLabel),
                    trailing: user.departmentId != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Başka departmanda',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => Navigator.pop(context, user),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedUser != null && mounted) {
      try {
        final repo = ref.read(requestRepositoryProvider);
        await repo.assignUserToDepartment(
          userId: selectedUser.id,
          departmentId: widget.department.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${selectedUser.fullName} departmana atandı')),
          );
          _loadAssignedUsers();
          ref.invalidate(assignableUsersProvider);
        }
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${e.message}')),
          );
        }
      }
    }
  }

  Future<void> _removeUserFromDepartment(DepartmentUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Personeli Çıkar'),
        content: Text(
          '"${user.fullName}" adlı personeli bu departmandan çıkarmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(requestRepositoryProvider);
        await repo.assignUserToDepartment(
          userId: user.id,
          departmentId: null, // null = departmandan çıkar
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.fullName} departmandan çıkarıldı')),
          );
          _loadAssignedUsers();
          ref.invalidate(assignableUsersProvider);
        }
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${e.message}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.department.name),
        actions: [
          IconButton(
            onPressed: _showAssignUserDialog,
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Personel Ekle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: colors.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz personel atanmamış',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bu departmana personel eklemek için\n+ butonuna tıklayın',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.outline,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _showAssignUserDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Personel Ekle'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAssignedUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _assignedUsers.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.people, color: colors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Atanmış Personel',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${_assignedUsers.length} kişi bu departmanda',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _showAssignUserDialog,
                                  icon: const Icon(Icons.person_add),
                                  tooltip: 'Personel Ekle',
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final user = _assignedUsers[index - 1];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            child: Text(
                              user.fullName.isNotEmpty
                                  ? user.fullName[0].toUpperCase()
                                  : '?',
                              style:
                                  TextStyle(color: colors.onPrimaryContainer),
                            ),
                          ),
                          title: Text(user.fullName),
                          subtitle: Text(user.roleLabel),
                          trailing: IconButton(
                            onPressed: () => _removeUserFromDepartment(user),
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: colors.error,
                            ),
                            tooltip: 'Departmandan Çıkar',
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _assignedUsers.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showAssignUserDialog,
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }
}

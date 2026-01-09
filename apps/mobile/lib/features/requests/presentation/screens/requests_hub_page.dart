import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/providers/auth_provider.dart';
import '../../data/request_repository.dart';
import '../../domain/models/branch_request.dart';
import '../../domain/models/equipment_request_type.dart';
import '../../domain/models/malfunction_issue_type.dart';
import '../../domain/models/request_category.dart';
import '../../domain/models/request_status.dart';
import 'request_form_page.dart';
import '../widgets/request_category_theme.dart';

class RequestsHubPage extends ConsumerStatefulWidget {
  const RequestsHubPage({super.key});

  @override
  ConsumerState<RequestsHubPage> createState() => _RequestsHubPageState();
}

class _RequestsHubPageState extends ConsumerState<RequestsHubPage> {
  Future<void> _refresh() {
    return ref.refresh(personalRequestsProvider.future);
  }

  Future<void> _showRequestDetails(BranchRequest request) async {
    final result = await showModalBottomSheet<_RequestDetailsResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RequestDetailsSheet(request: request),
    );

    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case _RequestDetailsResult.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep iptal edildi.')),
        );
        ref.invalidate(personalRequestsProvider);
        break;
      case _RequestDetailsResult.edit:
        final updated = await Navigator.of(context).push<BranchRequest>(
          MaterialPageRoute(
            builder: (_) => RequestFormPage.edit(request: request),
          ),
        );
        if (!mounted) {
          return;
        }
        if (updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Talep güncellendi.')),
          );
          ref.invalidate(personalRequestsProvider);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(personalRequestsProvider);
    final user = ref.watch(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );
    final bottomPadding =
        MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight;

    const categories = RequestCategoryThemes.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Talepler'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Talep Kategorileri',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final definition = categories[index];
                    return _RequestCategoryCard(
                      definition: definition,
                      onTap: user?.branchId == null
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              final result = await navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => RequestFormPage(
                                    category: definition.category,
                                  ),
                                ),
                              );
                              if (!mounted || result is! BranchRequest) {
                                return;
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${definition.title} oluşturuldu.',
                                  ),
                                ),
                              );
                              ref.invalidate(personalRequestsProvider);
                            },
                    );
                  },
                  childCount: categories.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Son Taleplerim',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyStateCard(
                        message:
                            'Henüz talep oluşturmadınız. Üstteki kategorilerden birini seçerek başlayabilirsiniz.',
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final request = requests[index];
                      final definition =
                          RequestCategoryThemes.of(request.category);
                      return _RequestListTile(
                        request: request,
                        definition: definition,
                        onTap: () => _showRequestDetails(request),
                      );
                    },
                    childCount: requests.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _EmptyStateCard(
                    message:
                        'Talepleriniz yüklenirken bir hata oluştu. Yeniden denemek için aşağı kaydırın.\n$error',
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: bottomPadding + 16),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RequestDetailsResult {
  cancelled,
  edit,
}

class _RequestCategoryCard extends StatelessWidget {
  const _RequestCategoryCard({
    required this.definition,
    this.onTap,
  });

  final RequestCategoryThemeData definition;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: definition.color.withValues(alpha: 0.12),
          border: Border.all(color: definition.color.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: definition.color,
              foregroundColor: Colors.white,
              child: Icon(definition.icon),
            ),
            const SizedBox(height: 12),
            Text(
              definition.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              definition.description,
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: definition.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestDetailsSheet extends ConsumerStatefulWidget {
  const _RequestDetailsSheet({required this.request});

  final BranchRequest request;

  @override
  ConsumerState<_RequestDetailsSheet> createState() =>
      _RequestDetailsSheetState();
}

class _RequestDetailsSheetState extends ConsumerState<_RequestDetailsSheet> {
  bool _isCancelling = false;
  final Map<String, Future<String?>> _attachmentUrlFutures =
      <String, Future<String?>>{};

  static const String _storageBucket = 'request-files';

  bool get _canModify {
    final status = widget.request.status;
    return status == RequestStatus.pending ||
        status == RequestStatus.inProgress;
  }

  List<String> get _attachmentReferences {
    final attachments = widget.request.payload?['attachments'];
    if (attachments is List) {
      return attachments
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Future<void> _handleCancel() async {
    if (!_canModify || _isCancelling) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Talebi iptal et'),
        content: const Text(
          'Talebi iptal etmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isCancelling = true);

    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.updateStatus(
        requestId: widget.request.id,
        status: RequestStatus.cancelled,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_RequestDetailsResult.cancelled);
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Talep iptal edilemedi: ${error.message}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  void _handleEdit() {
    if (!_canModify) {
      return;
    }
    Navigator.of(context).pop(_RequestDetailsResult.edit);
  }

  Future<String?> _getAttachmentUrl(String reference) {
    return _attachmentUrlFutures.putIfAbsent(reference, () async {
      final storage = Supabase.instance.client.storage.from(_storageBucket);

      String? path;
      if (reference.startsWith('http')) {
        path = _extractStoragePath(reference);
        if (path == null) {
          return reference;
        }
      } else {
        path = reference;
      }

      try {
        return await storage.createSignedUrl(path, 60 * 60);
      } catch (_) {
        if (reference.startsWith('http')) {
          return reference;
        }
        return null;
      }
    });
  }

  String? _extractStoragePath(String reference) {
    try {
      final uri = Uri.parse(reference);
      if (!uri.pathSegments.contains(_storageBucket)) {
        return null;
      }
      final bucketIndex = uri.pathSegments.indexOf(_storageBucket);
      if (bucketIndex == -1 || bucketIndex + 1 >= uri.pathSegments.length) {
        return null;
      }
      final segments = uri.pathSegments.sublist(bucketIndex + 1);
      return segments.join('/');
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAttachmentReference(String reference) async {
    final resolvedUrl = await _getAttachmentUrl(reference);
    if (!mounted) {
      return;
    }
    if (resolvedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görsel yüklenemedi.')),
      );
      return;
    }
    _openImage(resolvedUrl);
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, _, __) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: Colors.white54),
                            SizedBox(height: 8),
                            Text(
                              'Görsel yüklenemedi',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final formattedDate = _formatDate(date.toLocal());
    final hour = date.toLocal().hour.toString().padLeft(2, '0');
    final minute = date.toLocal().minute.toString().padLeft(2, '0');
    return '$formattedDate $hour:$minute';
  }

  String? _formatLeaveRange(Map<String, dynamic> payload) {
    final startIso = payload['start_date'] as String?;
    final endIso = payload['end_date'] as String?;
    final start = startIso == null ? null : DateTime.tryParse(startIso);
    final end = endIso == null ? null : DateTime.tryParse(endIso);
    if (start == null || end == null) {
      return null;
    }
    return '${_formatDate(start.toLocal())} - ${_formatDate(end.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final theme = Theme.of(context);
    final definition = RequestCategoryThemes.of(request.category);
    final attachmentReferences = _attachmentReferences;
    final payload = request.payload ?? const <String, dynamic>{};
    final malfunctionLabel = payload['malfunction_type_label'] as String? ??
        MalfunctionIssueTypeX.maybeFromValue(
                payload['malfunction_type'] as String?)
            ?.label;
    final malfunctionDescription =
        payload['malfunction_type_description'] as String?;
    final equipmentLabel = payload['equipment_type_label'] as String? ??
        EquipmentRequestTypeX.maybeFromValue(
                payload['equipment_type'] as String?)
            ?.label;
    final equipmentDescription =
        payload['equipment_type_description'] as String?;
    final leaveRangeText = widget.request.category == RequestCategory.leave
        ? _formatLeaveRange(payload)
        : null;

    final canModify = _canModify;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: definition.color,
                      foregroundColor: Colors.white,
                      child: Icon(definition.icon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                backgroundColor:
                                    definition.color.withValues(alpha: 0.15),
                                label: Text(
                                  definition.title,
                                  style: TextStyle(
                                    color: definition.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _StatusChip(status: request.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabelValue(context, 'Durum', request.status.label),
                _buildLabelValue(
                  context,
                  'Oluşturma Zamanı',
                  _formatDateTime(request.createdAt),
                ),
                _buildLabelValue(
                  context,
                  'Son Güncelleme',
                  _formatDateTime(request.updatedAt),
                ),
                if (request.targetDepartment != null &&
                    request.targetDepartment!.isNotEmpty)
                  _buildLabelValue(
                    context,
                    'Hedef Birim',
                    request.targetDepartment!,
                  ),
                if (request.description != null &&
                    request.description!.isNotEmpty)
                  _buildLabelValue(
                    context,
                    'Açıklama',
                    request.description!,
                  ),
                if (request.category == RequestCategory.malfunction &&
                    malfunctionLabel != null)
                  _buildLabelValue(
                    context,
                    'Arıza Kategorisi',
                    malfunctionLabel,
                  ),
                if (request.category == RequestCategory.malfunction &&
                    malfunctionDescription != null &&
                    malfunctionDescription.isNotEmpty)
                  _buildLabelValue(
                    context,
                    'Kategori Açıklaması',
                    malfunctionDescription,
                  ),
                if (request.category == RequestCategory.equipment &&
                    equipmentLabel != null)
                  _buildLabelValue(
                    context,
                    'Ekipman Kategorisi',
                    equipmentLabel,
                  ),
                if (request.category == RequestCategory.equipment &&
                    equipmentDescription != null &&
                    equipmentDescription.isNotEmpty)
                  _buildLabelValue(
                    context,
                    'Kategori Açıklaması',
                    equipmentDescription,
                  ),
                if (leaveRangeText != null)
                  _buildLabelValue(
                    context,
                    'İzin Aralığı',
                    leaveRangeText,
                  ),
                if (attachmentReferences.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Görseller',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: attachmentReferences.map((reference) {
                      return FutureBuilder<String?>(
                        future: _getAttachmentUrl(reference),
                        builder: (context, snapshot) {
                          final resolvedUrl = snapshot.data;
                          Widget child;
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            child = Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          } else if (resolvedUrl == null ||
                              resolvedUrl.isEmpty) {
                            child = Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            );
                          } else {
                            child = ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                resolvedUrl,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            );
                          }

                          return GestureDetector(
                            onTap: resolvedUrl == null || resolvedUrl.isEmpty
                                ? () => _openAttachmentReference(reference)
                                : () => _openImage(resolvedUrl),
                            child: child,
                          );
                        },
                      );
                    }).toList(growable: false),
                  ),
                ] else if ((payload['attachment_count'] as int? ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Ek görseller mevcut ancak şu anda yüklenemiyor.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canModify ? _handleEdit : null,
                        icon: const Icon(Icons.edit),
                        label: const Text('Talebi Güncelle'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            canModify && !_isCancelling ? _handleCancel : null,
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: Text(_isCancelling
                            ? 'İptal ediliyor...'
                            : 'Talebi İptal Et'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelValue(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RequestListTile extends StatelessWidget {
  const _RequestListTile({
    required this.request,
    required this.definition,
    this.onTap,
  });

  final BranchRequest request;
  final RequestCategoryThemeData definition;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[];
    if (request.category == RequestCategory.malfunction) {
      final typeValue = request.payload?['malfunction_type'] as String?;
      final typeLabel =
          MalfunctionIssueTypeX.maybeFromValue(typeValue)?.label ??
              request.payload?['malfunction_type_label'] as String?;
      if (typeLabel != null && typeLabel.isNotEmpty) {
        subtitle.add('Arıza Kategorisi: $typeLabel');
      }
    }
    if (request.category == RequestCategory.equipment) {
      final typeValue = request.payload?['equipment_type'] as String?;
      final typeLabel =
          EquipmentRequestTypeX.maybeFromValue(typeValue)?.label ??
              request.payload?['equipment_type_label'] as String?;
      if (typeLabel != null && typeLabel.isNotEmpty) {
        subtitle.add('Ekipman Kategorisi: $typeLabel');
      }
    }

    if (request.category == RequestCategory.malfunction ||
        request.category == RequestCategory.equipment) {
      final attachments = request.payload?['attachments'];
      if (attachments is List && attachments.isNotEmpty) {
        subtitle.add('Ek görsel: ${attachments.length} adet');
      } else {
        final attachmentCount =
            request.payload?['attachment_count'] as int? ?? 0;
        if (attachmentCount > 0) {
          subtitle.add('Ek görsel: $attachmentCount adet');
        }
      }
    }
    if (request.description != null && request.description!.isNotEmpty) {
      subtitle.add(request.description!);
    }
    if (request.targetDepartment != null &&
        request.targetDepartment!.isNotEmpty) {
      subtitle.add('Birim: ${request.targetDepartment}');
    }
    if (request.category == RequestCategory.leave && request.payload != null) {
      final start = request.payload?['start_date'] as String?;
      final end = request.payload?['end_date'] as String?;
      if (start != null && end != null) {
        subtitle.add('İzin Aralığı: ${_formatDateRange(start, end)}');
      }
    }

    return Card(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: definition.color,
          foregroundColor: Colors.white,
          child: Icon(definition.icon),
        ),
        title: Text(request.title),
        subtitle: subtitle.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(subtitle.join('\n')),
              ),
        onTap: onTap,
        trailing: _StatusChip(status: request.status),
      ),
    );
  }

  String _formatDateRange(String startIso, String endIso) {
    final start = DateTime.tryParse(startIso)?.toLocal();
    final end = DateTime.tryParse(endIso)?.toLocal();
    if (start == null || end == null) {
      return 'Belirtilmedi';
    }
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    late final Color background;
    late final Color foreground;

    switch (status) {
      case RequestStatus.pending:
        background = colorScheme.secondaryContainer;
        foreground = colorScheme.onSecondaryContainer;
        break;
      case RequestStatus.inProgress:
        background = colorScheme.tertiaryContainer;
        foreground = colorScheme.onTertiaryContainer;
        break;
      case RequestStatus.resolved:
        background = Colors.green.withValues(alpha: 0.16);
        foreground = Colors.green.shade800;
        break;
      case RequestStatus.cancelled:
        background = Colors.grey.withValues(alpha: 0.16);
        foreground = Colors.grey.shade700;
        break;
    }

    return Chip(
      label: Text(status.label),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

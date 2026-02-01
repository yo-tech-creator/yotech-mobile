import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/shared.dart';
import '../../domain/models/visual_audit_models.dart';
import '../../domain/providers/visual_audit_providers.dart';

/// Görsel Denetim Detay Sayfası
class VisualAuditDetailPage extends ConsumerStatefulWidget {
  final String taskId;

  const VisualAuditDetailPage({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<VisualAuditDetailPage> createState() =>
      _VisualAuditDetailPageState();
}

class _VisualAuditDetailPageState extends ConsumerState<VisualAuditDetailPage> {
  final _commentController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskAsync = ref.watch(visualAuditTaskProvider(widget.taskId));
    final photosAsync = ref.watch(visualAuditPhotosProvider(widget.taskId));
    final commentsAsync = ref.watch(visualAuditCommentsProvider(widget.taskId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Görev Detayı'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorState(
          message: 'Görev yüklenemedi',
          onRetry: () {
            ref.invalidate(visualAuditTaskProvider(widget.taskId));
          },
        ),
        data: (task) {
          if (task == null) {
            return const AppEmptyState(
              icon: Icons.error_outline,
              title: 'Görev Bulunamadı',
              subtitle: 'Bu görev artık mevcut değil.',
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Görev bilgisi kartı
                      _buildTaskInfoCard(context, theme, task),
                      const SizedBox(height: 20),

                      // Fotoğraflar bölümü
                      _buildPhotosSection(context, theme, task, photosAsync),
                      const SizedBox(height: 20),

                      // Yorumlar bölümü
                      _buildCommentsSection(context, theme, commentsAsync),
                    ],
                  ),
                ),
              ),

              // Alt bar - yorum yazma
              _buildBottomBar(context, theme, task),
            ],
          );
        },
      ),
      floatingActionButton: taskAsync.whenOrNull(
        data: (task) {
          if (task == null) return null;
          if (task.status == VisualAuditStatus.approved) return null;

          return FloatingActionButton.extended(
            onPressed: _isUploading ? null : () => _pickAndUploadPhoto(task),
            backgroundColor: const Color(0xFF3B82F6),
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.add_a_photo_rounded, color: Colors.white),
            label: Text(
              _isUploading ? 'Yükleniyor...' : 'Fotoğraf Ekle',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskInfoCard(
      BuildContext context, ThemeData theme, VisualAuditTask task) {
    final color = _parseColor(task.sectionColor);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getSectionIcon(task.sectionIcon),
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.sectionName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.templateName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bilgi satırları
          _buildInfoRow(
            theme,
            Icons.schedule_rounded,
            'Planlanan Saat',
            task.displayTime,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            theme,
            Icons.timer_outlined,
            'Son Teslim',
            DateFormat('HH:mm', 'tr').format(task.deadlineAt),
            isWarning: task.isOverdue,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            theme,
            Icons.photo_library_outlined,
            'Fotoğraf',
            '${task.photoCount} / ${task.minPhotos} minimum',
            isSuccess: task.photoCount >= task.minPhotos,
          ),

          if (task.completedAt != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              theme,
              Icons.check_circle_outline,
              'Tamamlanma',
              DateFormat('HH:mm', 'tr').format(task.completedAt!),
              isSuccess: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    bool isWarning = false,
    bool isSuccess = false,
  }) {
    Color valueColor = theme.colorScheme.onSurface;
    if (isWarning) valueColor = Colors.orange;
    if (isSuccess) valueColor = Colors.green;

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection(
    BuildContext context,
    ThemeData theme,
    VisualAuditTask task,
    AsyncValue<List<VisualAuditPhoto>> photosAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_library_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Fotoğraflar',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        photosAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => const Text('Fotoğraflar yüklenemedi'),
          data: (photos) {
            if (photos.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Henüz fotoğraf eklenmedi',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return _buildPhotoCard(context, theme, photo);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoCard(
      BuildContext context, ThemeData theme, VisualAuditPhoto photo) {
    return GestureDetector(
      onTap: () => _showPhotoFullScreen(context, photo),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                photo.thumbnailUrl ?? photo.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
              ),

              // Yükleyen bilgisi
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    DateFormat('HH:mm').format(photo.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsSection(
    BuildContext context,
    ThemeData theme,
    AsyncValue<List<VisualAuditComment>> commentsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Yorumlar',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        commentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Yorumlar yüklenemedi'),
          data: (comments) {
            if (comments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Henüz yorum yok',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              );
            }

            return Column(
              children:
                  comments.map((c) => _buildCommentItem(theme, c)).toList(),
            );
          },
        ),

        // FAB için boşluk
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildCommentItem(ThemeData theme, VisualAuditComment comment) {
    final isManager = comment.isFromManager;
    Color? bgColor;
    IconData? typeIcon;

    switch (comment.commentType) {
      case VisualAuditCommentType.approval:
        bgColor = Colors.green.withOpacity(0.1);
        typeIcon = Icons.check_circle;
        break;
      case VisualAuditCommentType.rejection:
      case VisualAuditCommentType.revisionRequest:
        bgColor = Colors.orange.withOpacity(0.1);
        typeIcon = Icons.error_outline;
        break;
      default:
        bgColor = isManager
            ? theme.colorScheme.primary.withOpacity(0.08)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (typeIcon != null) ...[
                Icon(typeIcon,
                    size: 16,
                    color:
                        comment.commentType == VisualAuditCommentType.approval
                            ? Colors.green
                            : Colors.orange),
                const SizedBox(width: 6),
              ],
              Text(
                comment.userName,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isManager ? theme.colorScheme.primary : null,
                ),
              ),
              if (isManager) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Yönetici',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                DateFormat('HH:mm').format(comment.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.message,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
      BuildContext context, ThemeData theme, VisualAuditTask task) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Yorum yazın...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                filled: true,
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sendComment,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(VisualAuditTask task) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(image.path);
      final fileName =
          '${task.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'visual-audits/${task.id}/$fileName';

      // Supabase Storage'a yükle
      await Supabase.instance.client.storage
          .from('visual-audits')
          .upload(storagePath, file);

      // Public URL al
      final photoUrl = Supabase.instance.client.storage
          .from('visual-audits')
          .getPublicUrl(storagePath);

      // Veritabanına kaydet
      final success =
          await ref.read(visualAuditPhotoUploadProvider.notifier).uploadPhoto(
                taskId: task.id,
                photoUrl: photoUrl,
              );

      if (success && mounted) {
        // Fotoğrafları ve görevi yenile
        ref.invalidate(visualAuditPhotosProvider(task.id));
        ref.invalidate(visualAuditTaskProvider(task.id));
        ref.invalidate(visualAuditTasksProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf yüklendi ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendComment() async {
    final message = _commentController.text.trim();
    if (message.isEmpty) return;

    final success =
        await ref.read(visualAuditCommentProvider.notifier).addComment(
              taskId: widget.taskId,
              message: message,
            );

    if (success && mounted) {
      _commentController.clear();
      ref.invalidate(visualAuditCommentsProvider(widget.taskId));
    }
  }

  void _showPhotoFullScreen(BuildContext context, VisualAuditPhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              photo.uploaderName,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                photo.photoUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}
    return const Color(0xFF3B82F6);
  }

  IconData _getSectionIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'apple':
      case 'manav':
        return Icons.eco_rounded;
      case 'sandwich':
      case 'sarkuteri':
        return Icons.lunch_dining_rounded;
      case 'beef':
      case 'kasap':
        return Icons.restaurant_rounded;
      case 'croissant':
      case 'unlu':
        return Icons.bakery_dining_rounded;
      case 'banknote':
      case 'kasa':
        return Icons.point_of_sale_rounded;
      case 'store':
        return Icons.store_rounded;
      default:
        return Icons.camera_alt_rounded;
    }
  }
}

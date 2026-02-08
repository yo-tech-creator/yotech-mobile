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
  final List<File> _pendingPhotos = [];
  int _uploadProgress = 0;

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
    final canAddPhotos = task.status != VisualAuditStatus.approved;

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

        // Fotoğraf ekleme butonları
        if (canAddPhotos) ...[
          _buildPhotoActionButtons(context, theme, task),
          const SizedBox(height: 12),
        ],

        // Yükleme durumu
        if (_isUploading) ...[
          _buildUploadProgress(theme),
          const SizedBox(height: 12),
        ],

        // Bekleyen fotoğraflar önizlemesi
        if (_pendingPhotos.isNotEmpty) ...[
          _buildPendingPhotosPreview(context, theme, task),
          const SizedBox(height: 12),
        ],

        // Mevcut fotoğraflar
        photosAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => const Text('Fotoğraflar yüklenemedi'),
          data: (photos) {
            if (photos.isEmpty && _pendingPhotos.isEmpty) {
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
                    if (canAddPhotos) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Yukarıdaki butonları kullanarak fotoğraf ekleyin',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            return Column(
              children: [
                GridView.builder(
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
                ),
                // Görevi Tamamla butonu
                if (photos.length >= task.minPhotos &&
                    task.status != VisualAuditStatus.completed &&
                    task.status != VisualAuditStatus.approved) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _completeTask(task),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Görevi Tamamla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                // Görev tamamlandı bilgisi
                if (task.status == VisualAuditStatus.completed) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Görev Tamamlandı ✓',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoActionButtons(
      BuildContext context, ThemeData theme, VisualAuditTask task) {
    return Row(
      children: [
        // Kamera butonu
        Expanded(
          child: _buildActionButton(
            theme,
            icon: Icons.camera_alt_rounded,
            label: 'Fotoğraf Çek',
            color: const Color(0xFF3B82F6),
            onTap: _isUploading ? null : () => _openCamera(task),
          ),
        ),
        const SizedBox(width: 10),
        // Galeri butonu
        Expanded(
          child: _buildActionButton(
            theme,
            icon: Icons.photo_library_rounded,
            label: 'Galeriden Seç',
            color: const Color(0xFF10B981),
            onTap: _isUploading ? null : () => _pickFromGallery(task),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadProgress(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fotoğraflar yükleniyor...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _pendingPhotos.isEmpty
                      ? null
                      : _uploadProgress / _pendingPhotos.length,
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPhotosPreview(
      BuildContext context, ThemeData theme, VisualAuditTask task) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${_pendingPhotos.length} fotoğraf yüklenmeye hazır',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Temizle butonu
              TextButton.icon(
                onPressed: () {
                  setState(() => _pendingPhotos.clear());
                },
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Temizle'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Önizleme grid
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 80,
                  height: 80,
                  margin: EdgeInsets.only(
                      right: index < _pendingPhotos.length - 1 ? 8 : 0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _pendingPhotos[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Silme butonu
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _pendingPhotos.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Yükle butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : () => _uploadPendingPhotos(task),
              icon: const Icon(Icons.cloud_upload_rounded),
              label: Text('${_pendingPhotos.length} Fotoğrafı Yükle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
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

        // Alt boşluk
        const SizedBox(height: 16),
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

  // ============================================
  // KAMERA - WhatsApp tarzı çoklu fotoğraf çekme
  // ============================================
  Future<void> _openCamera(VisualAuditTask task) async {
    final picker = ImagePicker();

    // Kamerayı aç
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    // Fotoğrafı listeye ekle
    setState(() {
      _pendingPhotos.add(File(image.path));
    });

    // Kullanıcıya seçenek sun: Devam mı yükle mi?
    if (!mounted) return;

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotoğraf Eklendi'),
        content: Text(
          '${_pendingPhotos.length} fotoğraf hazır.\n\nBaşka fotoğraf çekmek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Yüklemeye Geç'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (shouldContinue == true && mounted) {
      _openCamera(task);
    }
  }

  // ============================================
  // GALERİ - Çoklu fotoğraf seçme
  // ============================================
  Future<void> _pickFromGallery(VisualAuditTask task) async {
    final picker = ImagePicker();

    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (images.isEmpty) return;

    setState(() {
      _pendingPhotos.addAll(images.map((img) => File(img.path)));
    });
  }

  // ============================================
  // FOTOĞRAFLARı YÜKLE
  // ============================================
  Future<void> _uploadPendingPhotos(VisualAuditTask task) async {
    if (_pendingPhotos.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    final photosToUpload = List<File>.from(_pendingPhotos);
    int successCount = 0;
    String? lastError;

    try {
      for (int i = 0; i < photosToUpload.length; i++) {
        final file = photosToUpload[i];
        final fileName =
            '${task.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        // Storage path - bucket adı olmadan sadece dosya yolu
        final storagePath = '${task.id}/$fileName';

        try {
          // Supabase Storage'a yükle
          await Supabase.instance.client.storage
              .from('visual-audits')
              .upload(storagePath, file);

          // Public URL al
          final photoUrl = Supabase.instance.client.storage
              .from('visual-audits')
              .getPublicUrl(storagePath);

          // Veritabanına kaydet - doğrudan Supabase kullan
          await Supabase.instance.client.rpc(
            'upload_visual_audit_photo',
            params: {
              'p_task_id': task.id,
              'p_photo_url': photoUrl,
            },
          );

          successCount++;
        } catch (e) {
          debugPrint('Fotoğraf yükleme hatası: $e');
          lastError = e.toString();
        }

        if (mounted) {
          setState(() {
            _uploadProgress = i + 1;
          });
        }
      }

      if (mounted) {
        // Fotoğrafları ve görevi yenile
        ref.invalidate(visualAuditPhotosProvider(task.id));
        ref.invalidate(visualAuditTaskProvider(task.id));
        ref.invalidate(visualAuditTasksProvider);

        // Pending listeyi temizle
        setState(() {
          _pendingPhotos.clear();
        });

        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount fotoğraf yüklendi ✓'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (lastError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Yükleme hatası: $lastError'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
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
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  // ============================================
  // GÖREVİ TAMAMLA
  // ============================================
  Future<void> _completeTask(VisualAuditTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Görevi Tamamla'),
          ],
        ),
        content: const Text(
          'Bu görevi tamamlamak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('visual_audit_tasks').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', task.id);

      if (mounted) {
        ref.invalidate(visualAuditTaskProvider(task.id));
        ref.invalidate(visualAuditTasksProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görev tamamlandı! ✓'),
            backgroundColor: Colors.green,
          ),
        );
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
    }
  }

  Future<void> _sendComment() async {
    final message = _commentController.text.trim();
    if (message.isEmpty) return;

    try {
      // Doğrudan Supabase RPC kullan - provider dispose sorununu önle
      await Supabase.instance.client.rpc('add_visual_audit_comment', params: {
        'p_task_id': widget.taskId,
        'p_message': message,
        'p_comment_type': 'comment',
      });

      if (mounted) {
        _commentController.clear();
        ref.invalidate(visualAuditCommentsProvider(widget.taskId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yorum gönderilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

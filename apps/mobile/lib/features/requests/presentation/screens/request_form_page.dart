import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/providers/auth_provider.dart';
import '../../data/request_repository.dart';
import '../../domain/models/branch_request.dart';
import '../../domain/models/equipment_request_type.dart';
import '../../domain/models/request_category.dart';
import '../../domain/models/malfunction_issue_type.dart';
import '../../domain/models/leave_request_type.dart';

class RequestFormPage extends ConsumerStatefulWidget {
  RequestFormPage({
    required this.category,
    this.existingRequest,
    super.key,
  }) : assert(
          existingRequest == null || existingRequest.category == category,
          'Düzenleme sırasında kategori değiştirilemez.',
        );

  factory RequestFormPage.edit({
    required BranchRequest request,
    Key? key,
  }) {
    return RequestFormPage(
      key: key,
      category: request.category,
      existingRequest: request,
    );
  }

  final RequestCategory category;
  final BranchRequest? existingRequest;

  @override
  ConsumerState<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends ConsumerState<RequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetDepartmentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_PendingAttachment> _attachments = <_PendingAttachment>[];
  final List<String> _existingAttachments = <String>[];
  final Map<String, Future<String?>> _attachmentUrlFutures =
      <String, Future<String?>>{};

  static const String _storageBucket = 'request-files';

  static const int _maxAttachmentCount = 6;
  String? _selectedMalfunctionType;
  String? _selectedEquipmentType;
  String? _selectedLeaveType;
  double? _annualLeaveBalanceDays;
  bool _isFetchingLeaveBalance = false;
  String? _leaveBalanceError;

  DateTimeRange? _leaveRange;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingRequest != null;
  bool get _supportsAttachments =>
      widget.category == RequestCategory.malfunction ||
      widget.category == RequestCategory.equipment;
  bool get _isAnnualLeaveSelected =>
      _selectedLeaveType == LeaveRequestType.annual.value;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRequest;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _targetDepartmentController.text = existing.targetDepartment ?? '';
    }

    final payload = existing?.payload ?? const <String, dynamic>{};

    switch (widget.category) {
      case RequestCategory.malfunction:
        final typeValue = payload['malfunction_type'] as String?;
        if (typeValue != null && typeValue.isNotEmpty) {
          _selectedMalfunctionType = typeValue;
        }
        _loadExistingAttachments(payload);
        break;
      case RequestCategory.leave:
        final startIso = payload['start_date'] as String?;
        final endIso = payload['end_date'] as String?;
        final start = startIso == null ? null : DateTime.tryParse(startIso);
        final end = endIso == null ? null : DateTime.tryParse(endIso);
        if (start != null && end != null) {
          _leaveRange = DateTimeRange(
            start: start.toLocal(),
            end: end.toLocal(),
          );
        }
        final leaveTypeValue = payload['leave_type'] as String?;
        if (leaveTypeValue != null && leaveTypeValue.isNotEmpty) {
          _selectedLeaveType = leaveTypeValue;
        }
        final balanceSnapshot = payload['annual_leave_balance_snapshot'];
        if (balanceSnapshot is num) {
          _annualLeaveBalanceDays = balanceSnapshot.toDouble();
        }
        break;
      case RequestCategory.equipment:
        final typeValue = payload['equipment_type'] as String?;
        if (typeValue != null && typeValue.isNotEmpty) {
          _selectedEquipmentType = typeValue;
        }
        _loadExistingAttachments(payload);
        break;
      case RequestCategory.other:
        _loadExistingAttachments(payload);
        break;
    }

    if (widget.category == RequestCategory.leave) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAnnualLeaveBalance();
      });
    }
  }

  void _loadExistingAttachments(Map<String, dynamic> payload) {
    final attachments = payload['attachments'];
    if (attachments is List) {
      _existingAttachments
        ..clear()
        ..addAll(attachments.whereType<String>());
    }
  }

  Future<void> _loadAnnualLeaveBalance() async {
    if (!mounted) {
      return;
    }
    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      setState(() {
        _leaveBalanceError = 'Oturum bulunamadı.';
      });
      return;
    }

    setState(() {
      _isFetchingLeaveBalance = true;
      _leaveBalanceError = null;
    });

    try {
      final response = await client
          .from('users')
          .select('annual_leave_days, used_leave_days')
          .eq('id', authUser.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      if (response == null) {
        setState(() {
          _annualLeaveBalanceDays = null;
          _leaveBalanceError = 'İzin hakkı bilgisine ulaşılamadı.';
        });
        return;
      }

      final total = (response['annual_leave_days'] as num?)?.toDouble();
      final used = (response['used_leave_days'] as num?)?.toDouble();

      if (total == null) {
        setState(() {
          _annualLeaveBalanceDays = null;
          _leaveBalanceError = 'İzin hakkı tanımlı değil.';
        });
        return;
      }

      final remaining = total - (used ?? 0);
      setState(() {
        _annualLeaveBalanceDays = remaining < 0 ? 0 : remaining;
        _leaveBalanceError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _leaveBalanceError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLeaveBalance = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetDepartmentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );

    if (user?.branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Talep oluşturmak için şubeye atanmış olmanız gerekir.'),
        ),
      );
      return;
    }

    final currentUser = user!;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(requestRepositoryProvider);
      final payload = <String, dynamic>{};

      String? attachmentFolder;
      String? attachmentTypeValue;

      switch (widget.category) {
        case RequestCategory.leave:
          if (_leaveRange == null) {
            throw const FormatException(
                'İzin başlangıç ve bitiş tarihini seçin.');
          }
          if (_selectedLeaveType == null || _selectedLeaveType!.isEmpty) {
            throw const FormatException('İzin türünü seçin.');
          }
          payload['start_date'] = _leaveRange!.start.toUtc().toIso8601String();
          payload['end_date'] = _leaveRange!.end.toUtc().toIso8601String();
          final leaveType = LeaveRequestTypeX.fromValue(_selectedLeaveType!);
          payload['leave_type'] = leaveType.value;
          payload['leave_type_label'] = leaveType.label;
          final leaveDescription = leaveType.description;
          if (leaveDescription != null && leaveDescription.isNotEmpty) {
            payload['leave_type_description'] = leaveDescription;
          }
          if (leaveType == LeaveRequestType.annual) {
            final balance = _annualLeaveBalanceDays;
            if (balance != null) {
              payload['annual_leave_balance_snapshot'] = balance;
            }
            payload['annual_leave_checked_at'] =
                DateTime.now().toUtc().toIso8601String();
          }
          break;
        case RequestCategory.malfunction:
          if (_selectedMalfunctionType == null) {
            throw const FormatException('Arıza kategorisini seçin.');
          }
          final issueType =
              MalfunctionIssueTypeX.fromValue(_selectedMalfunctionType!);
          payload['malfunction_type'] = issueType.value;
          payload['malfunction_type_label'] = issueType.label;
          final description = issueType.description;
          if (description != null && description.isNotEmpty) {
            payload['malfunction_type_description'] = description;
          }
          attachmentFolder = 'malfunctions';
          attachmentTypeValue = issueType.value;
          break;
        case RequestCategory.equipment:
          if (_selectedEquipmentType == null) {
            throw const FormatException('Ekipman kategorisini seçin.');
          }
          final equipmentType =
              EquipmentRequestTypeX.fromValue(_selectedEquipmentType!);
          payload['equipment_type'] = equipmentType.value;
          payload['equipment_type_label'] = equipmentType.label;
          final equipmentDescription = equipmentType.description;
          if (equipmentDescription != null && equipmentDescription.isNotEmpty) {
            payload['equipment_type_description'] = equipmentDescription;
          }
          attachmentFolder = 'equipment';
          attachmentTypeValue = equipmentType.value;
          break;
        case RequestCategory.other:
          // no additional payload fields
          break;
      }

      List<String> uploadedReferences = const <String>[];
      if (attachmentFolder != null && attachmentTypeValue != null) {
        if (_attachments.isNotEmpty) {
          uploadedReferences = await _uploadAttachments(
            tenantId: currentUser.tenantId,
            branchId: currentUser.branchId!,
            userId: currentUser.id,
            categoryFolder: attachmentFolder,
            typeValue: attachmentTypeValue,
          );
        }

        final combinedAttachments = <String>[
          ..._existingAttachments,
          ...uploadedReferences,
        ];
        if (combinedAttachments.isNotEmpty) {
          payload['attachments'] = combinedAttachments;
          payload['attachment_count'] = combinedAttachments.length;
        } else {
          payload.remove('attachments');
          payload.remove('attachment_count');
        }
      }

      final title = _titleController.text.trim();
      final descriptionText = _descriptionController.text.trim();
      final targetDepartment = _targetDepartmentController.text.trim();

      BranchRequest request;
      if (_isEditing) {
        request = await repo.updateRequest(
          requestId: widget.existingRequest!.id,
          title: title,
          description: descriptionText.isEmpty ? null : descriptionText,
          payload: payload.isEmpty ? null : payload,
          targetDepartment: targetDepartment.isEmpty ? null : targetDepartment,
        );
      } else {
        request = await repo.createRequest(
          category: widget.category,
          title: title,
          description: descriptionText.isEmpty ? null : descriptionText,
          branchId: currentUser.branchId!,
          payload: payload.isEmpty ? null : payload,
          targetDepartment: targetDepartment.isEmpty ? null : targetDepartment,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop<BranchRequest>(request);
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Talep kaydedilemedi: ${error.message}')),
      );
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickImages() async {
    final remainingSlots = _maxAttachmentCount -
        (_attachments.length + _existingAttachments.length);
    if (remainingSlots <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('En fazla $_maxAttachmentCount görsel ekleyebilirsiniz.'),
        ),
      );
      return;
    }

    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 80);
      if (files.isEmpty) {
        return;
      }

      final newAttachments = <_PendingAttachment>[];
      for (final file in files.take(remainingSlots)) {
        final data = await file.readAsBytes();
        if (data.lengthInBytes > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${file.name} 10 MB üzeri olduğu için eklenmedi.',
                ),
              ),
            );
          }
          continue;
        }
        newAttachments.add(
          _PendingAttachment(
            name: file.name,
            bytes: data,
            mimeType: _inferMimeType(file.name),
          ),
        );
      }

      if (newAttachments.isEmpty || !mounted) {
        return;
      }

      setState(() => _attachments.addAll(newAttachments));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görsel seçilirken bir hata oluştu: $error')),
      );
    }
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) {
      return;
    }
    setState(() => _attachments.removeAt(index));
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
    _openImagePreview(resolvedUrl);
  }

  void _openImagePreview(String imageUrl) {
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
                    imageUrl,
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

  Widget _buildAttachmentSection(BuildContext context) {
    final theme = Theme.of(context);
    final totalAttachmentCount =
        _existingAttachments.length + _attachments.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Görseller (opsiyonel)',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _pickImages,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            totalAttachmentCount == 0
                ? 'Fotoğraf ekle'
                : 'Fotoğraf ekle ($totalAttachmentCount/$_maxAttachmentCount)',
          ),
        ),
        if (_existingAttachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Yüklenmiş görseller',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _existingAttachments.map((reference) {
              return FutureBuilder<String?>(
                future: _getAttachmentUrl(reference),
                builder: (context, snapshot) {
                  Widget child;
                  if (snapshot.connectionState != ConnectionState.done) {
                    child = Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  } else {
                    final url = snapshot.data;
                    if (url == null || url.isEmpty) {
                      child = Container(
                        width: 80,
                        height: 80,
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
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      );
                    }
                  }

                  final resolvedUrl = snapshot.data;
                  return GestureDetector(
                    onTap: resolvedUrl == null || resolvedUrl.isEmpty
                        ? () => _openAttachmentReference(reference)
                        : () => _openImagePreview(resolvedUrl),
                    child: child,
                  );
                },
              );
            }).toList(growable: false),
          ),
        ],
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _attachments.asMap().entries.map((entry) {
              final index = entry.key;
              final attachment = entry.value;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      attachment.bytes,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isSubmitting
                            ? null
                            : () => _removeAttachment(index),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(growable: false),
          ),
        ],
      ],
    );
  }

  Future<List<String>> _uploadAttachments({
    required String tenantId,
    required String branchId,
    required String userId,
    required String categoryFolder,
    required String typeValue,
  }) async {
    final storage = Supabase.instance.client.storage.from(_storageBucket);
    final uploadedReferences = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (var index = 0; index < _attachments.length; index++) {
      final attachment = _attachments[index];
      final fileName =
          '${userId}_$timestamp-$index${_fileExtensionForMimeType(attachment.mimeType)}';
      final path = '$categoryFolder/$tenantId/$branchId/$typeValue/$fileName';
      await storage.uploadBinary(
        path,
        attachment.bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true,
          contentType: attachment.mimeType,
        ),
      );
      uploadedReferences.add(path);
    }

    return uploadedReferences;
  }

  String _inferMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  String _fileExtensionForMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
      case 'image/heif':
        return '.heic';
      default:
        return '.jpg';
    }
  }

  Future<void> _pickLeaveRange() async {
    final initialDate = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: initialDate.subtract(const Duration(days: 365)),
      lastDate: initialDate.add(const Duration(days: 365)),
      initialDateRange: _leaveRange,
    );
    if (range != null) {
      setState(() => _leaveRange = range);
    }
  }

  Widget _buildAnnualLeaveBalanceInfo(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    BoxDecoration decoration(Color borderColor, Color backgroundColor) {
      return BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      );
    }

    if (_isFetchingLeaveBalance) {
      final border = colorScheme.primary.withValues(alpha: 0.35);
      final background = colorScheme.primary.withValues(alpha: 0.12);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: decoration(border, background),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Güncel yıllık izin hakkı yükleniyor...',
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (_leaveBalanceError != null) {
      final border = colorScheme.error.withValues(alpha: 0.5);
      final background = colorScheme.error.withValues(alpha: 0.12);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: decoration(border, background),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Yıllık izin hakkı alınamadı: $_leaveBalanceError',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final balance = _annualLeaveBalanceDays;
    if (balance == null) {
      final border = colorScheme.secondary.withValues(alpha: 0.35);
      final background = colorScheme.secondary.withValues(alpha: 0.12);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: decoration(border, background),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Yıllık izin hakkı bilgisi bulunamadı.',
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final formattedBalance = balance % 1 == 0
        ? balance.toStringAsFixed(0)
        : balance.toStringAsFixed(1);
    final border = colorScheme.primary.withValues(alpha: 0.35);
    final background = colorScheme.primary.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: decoration(border, background),
      child: Row(
        children: [
          Icon(Icons.beach_access, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kalan yıllık izin hakkınız: $formattedBalance gün',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = _isEditing
        ? switch (widget.category) {
            RequestCategory.malfunction => 'Arıza Kaydını Güncelle',
            RequestCategory.equipment => 'Ekipman Talebini Güncelle',
            RequestCategory.leave => 'İzin Talebini Güncelle',
            RequestCategory.other => 'Talebi Güncelle',
          }
        : switch (widget.category) {
            RequestCategory.malfunction => 'Arıza Kaydı Oluştur',
            RequestCategory.equipment => 'Ekipman Talebi Oluştur',
            RequestCategory.leave => 'İzin Talebi Oluştur',
            RequestCategory.other => 'Talep Oluştur',
          };

    final titleHint = switch (widget.category) {
      RequestCategory.malfunction => 'Örnek: POS cihazı arızası',
      RequestCategory.equipment => 'Örnek: Yeni kasa için raf seti',
      RequestCategory.leave => 'Örnek: 12-15 Ağustos izin talebi',
      RequestCategory.other => 'Örnek: Şube içi duyuru isteği',
    };

    final descriptionHint = switch (widget.category) {
      RequestCategory.malfunction =>
        'Arızayı detaylandırın, gerekirse seri numarası ekleyin. Destek fotoğraflarını alttan ekleyebilirsiniz.',
      RequestCategory.equipment =>
        'İhtiyaç duyulan ekipmanı ve adetini belirtin.',
      RequestCategory.leave =>
        'İzin gerekçesini ve varsa temsilci bilgilerini ekleyin.',
      RequestCategory.other =>
        'Talep ile ilgili açıklamaları ve beklentileri yazın.',
    };

    final submitLabel = _isEditing ? 'Talebi Güncelle' : 'Talebi Gönder';
    final submittingLabel = _isEditing ? 'Kaydediliyor...' : 'Gönderiliyor...';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Başlık',
                  hintText: titleHint,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Başlık zorunlu';
                  }
                  return null;
                },
              ),
              if (widget.category == RequestCategory.malfunction) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMalfunctionType,
                  decoration: const InputDecoration(
                    labelText: 'Arıza Kategorisi',
                    helperText: 'Sorunun hangi gruba girdiğini seçin',
                  ),
                  isExpanded: true,
                  items: MalfunctionIssueType.values
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type.value,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(type.label),
                              if (type.description != null)
                                Text(
                                  type.description!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context).hintColor,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  selectedItemBuilder: (context) {
                    return MalfunctionIssueType.values
                        .map(
                          (type) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(type.label),
                          ),
                        )
                        .toList(growable: false);
                  },
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() => _selectedMalfunctionType = value);
                        },
                  validator: (value) {
                    if (widget.category != RequestCategory.malfunction) {
                      return null;
                    }
                    if (value == null || value.isEmpty) {
                      return 'Arıza kategorisi seçin';
                    }
                    return null;
                  },
                ),
              ],
              if (widget.category == RequestCategory.equipment) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEquipmentType,
                  decoration: const InputDecoration(
                    labelText: 'Ekipman Kategorisi',
                    helperText: 'İhtiyaç duyulan ekipman grubunu seçin',
                  ),
                  isExpanded: true,
                  items: EquipmentRequestType.values
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type.value,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(type.label),
                              if (type.description != null)
                                Text(
                                  type.description!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context).hintColor,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  selectedItemBuilder: (context) {
                    return EquipmentRequestType.values
                        .map(
                          (type) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(type.label),
                          ),
                        )
                        .toList(growable: false);
                  },
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() => _selectedEquipmentType = value);
                        },
                  validator: (value) {
                    if (widget.category != RequestCategory.equipment) {
                      return null;
                    }
                    if (value == null || value.isEmpty) {
                      return 'Ekipman kategorisi seçin';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Açıklama',
                  hintText: descriptionHint,
                ),
              ),
              if (_supportsAttachments) ...[
                const SizedBox(height: 16),
                _buildAttachmentSection(context),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetDepartmentController,
                decoration: const InputDecoration(
                  labelText: 'Hedef Birim (opsiyonel)',
                  hintText: 'Teknik ekip, insan kaynakları vb.',
                ),
              ),
              if (widget.category == RequestCategory.leave) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLeaveType,
                  decoration: const InputDecoration(
                    labelText: 'İzin Türü',
                    helperText: 'Talebinize uygun izin türünü seçin',
                  ),
                  isExpanded: true,
                  items: LeaveRequestType.values
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type.value,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(type.icon, size: 20),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(type.label),
                                    if (type.description != null)
                                      Text(
                                        type.description!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  Theme.of(context).hintColor,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  selectedItemBuilder: (context) {
                    return LeaveRequestType.values
                        .map(
                          (type) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(type.label),
                          ),
                        )
                        .toList(growable: false);
                  },
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() => _selectedLeaveType = value);
                          if (value == LeaveRequestType.annual.value &&
                              !_isFetchingLeaveBalance) {
                            _loadAnnualLeaveBalance();
                          }
                        },
                  validator: (value) {
                    if (widget.category != RequestCategory.leave) {
                      return null;
                    }
                    if (value == null || value.isEmpty) {
                      return 'İzin türü seçin';
                    }
                    return null;
                  },
                ),
                if (_isAnnualLeaveSelected) ...[
                  const SizedBox(height: 12),
                  _buildAnnualLeaveBalanceInfo(context),
                ],
                const SizedBox(height: 24),
                ListTile(
                  onTap: _pickLeaveRange,
                  title: Text(
                    _leaveRange == null
                        ? 'İzin tarih aralığını seçin'
                        : _formatLeaveRange(_leaveRange!),
                  ),
                  subtitle: const Text(
                    'Seçtiğiniz tarih aralığı talep onayı için gönderilecek.',
                  ),
                  trailing: TextButton(
                    onPressed: _pickLeaveRange,
                    child: const Text('Tarih Seç'),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isEditing ? Icons.save : Icons.send),
                label: Text(_isSubmitting ? submittingLabel : submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLeaveRange(DateTimeRange range) {
    final start = range.start;
    final end = range.end;
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _PendingAttachment {
  const _PendingAttachment({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
}

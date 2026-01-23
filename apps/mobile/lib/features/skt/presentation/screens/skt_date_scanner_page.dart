import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// SKT tarihini kameradan okuyan sayfa
class SktDateScannerPage extends StatefulWidget {
  const SktDateScannerPage({super.key});

  @override
  State<SktDateScannerPage> createState() => _SktDateScannerPageState();
}

class _SktDateScannerPageState extends State<SktDateScannerPage> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  String? _recognizedText;
  List<DateTime> _detectedDates = [];
  DateTime? _selectedDate;
  String? _errorMessage;
  File? _capturedImage;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SKT Tarihi Oku'),
        centerTitle: true,
        actions: [
          if (_selectedDate != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(_selectedDate),
              child: const Text('Kullan'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ürün ambalajındaki son kullanma tarihini kameraya gösterin. '
                      'Tarih otomatik olarak algılanacaktır.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Camera/Gallery Buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.camera_alt,
                    label: 'Fotoğraf Çek',
                    color: colors.primary,
                    isLoading: _isProcessing,
                    onTap: () => _captureImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.photo_library,
                    label: 'Galeriden Seç',
                    color: colors.secondary,
                    isLoading: _isProcessing,
                    onTap: () => _captureImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            if (_capturedImage != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _capturedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            if (_isProcessing) ...[
              const SizedBox(height: 32),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Metin analiz ediliyor...'),
                  ],
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_detectedDates.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Algılanan Tarihler',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_detectedDates.length, (index) {
                final date = _detectedDates[index];
                final isSelected = _selectedDate == date;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDate = date),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.calendar_today,
                            color:
                                isSelected ? colors.onPrimary : colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatDate(date),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isSelected
                                  ? colors.onPrimary
                                  : colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatRelativeDate(date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? colors.onPrimary.withValues(alpha: 0.8)
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            if (_recognizedText != null && _detectedDates.isEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields, color: colors.tertiary),
                        const SizedBox(width: 8),
                        Text(
                          'Algılanan Metin',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recognizedText!,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tarih formatı algılanamadı. Lütfen daha net bir fotoğraf çekin.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_selectedDate != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_selectedDate),
                icon: const Icon(Icons.check),
                label: Text('${_formatDate(_selectedDate!)} Tarihini Kullan'),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _recognizedText = null;
        _detectedDates = [];
        _selectedDate = null;
        _capturedImage = File(image.path);
      });

      await _processImage(image.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Fotoğraf alınırken hata oluştu: $e';
      });
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (!mounted) return;

      final text = recognizedText.text;
      final dates = _extractDates(text);

      setState(() {
        _isProcessing = false;
        _recognizedText = text.isEmpty ? null : text;
        _detectedDates = dates;
        if (dates.length == 1) {
          _selectedDate = dates.first;
        }
      });

      if (dates.isEmpty && text.isNotEmpty) {
        setState(() {
          _errorMessage =
              'Metinde tarih bulunamadı. Farklı bir açıdan deneyin.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Metin tanıma hatası: $e';
      });
    }
  }

  /// Metinden tarih formatlarını çıkarır
  List<DateTime> _extractDates(String text) {
    final dates = <DateTime>[];
    final now = DateTime.now();
    final currentYear = now.year;

    // Türkçe ve uluslararası tarih formatları
    final patterns = [
      // DD.MM.YYYY veya DD/MM/YYYY veya DD-MM-YYYY
      RegExp(r'(\d{1,2})[./\-](\d{1,2})[./\-](\d{4})'),
      // DD.MM.YY veya DD/MM/YY
      RegExp(r'(\d{1,2})[./\-](\d{1,2})[./\-](\d{2})(?!\d)'),
      // YYYY.MM.DD veya YYYY/MM/DD veya YYYY-MM-DD
      RegExp(r'(\d{4})[./\-](\d{1,2})[./\-](\d{1,2})'),
      // MM/YYYY veya MM.YYYY (ay/yıl)
      RegExp(r'(\d{1,2})[./\-](\d{4})'),
      // SKT: DD.MM.YYYY formatı
      RegExp(r'SKT[:\s]*(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})',
          caseSensitive: false),
      // EXP: DD.MM.YYYY formatı
      RegExp(r'EXP[:\s]*(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})',
          caseSensitive: false),
      // BB: DD.MM.YYYY formatı (Best Before)
      RegExp(r'BB[:\s]*(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        try {
          DateTime? date;
          final groups = match.groups([1, 2, 3]);

          if (pattern.pattern.startsWith(r'(\d{4})')) {
            // YYYY-MM-DD format
            final year = int.parse(groups[0]!);
            final month = int.parse(groups[1]!);
            final day = int.parse(groups[2]!);
            date = DateTime(year, month, day);
          } else if (pattern.pattern.contains(r'(\d{4})') &&
              groups[2] == null) {
            // MM/YYYY format
            final month = int.parse(groups[0]!);
            final year = int.parse(groups[1]!);
            // Ayın son günü
            date = DateTime(year, month + 1, 0);
          } else if (groups[2] != null) {
            // DD.MM.YY veya DD.MM.YYYY
            final day = int.parse(groups[0]!);
            final month = int.parse(groups[1]!);
            var year = int.parse(groups[2]!);

            // 2 haneli yılı 4 haneliye çevir
            if (year < 100) {
              year = year >= 50 ? 1900 + year : 2000 + year;
            }

            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              date = DateTime(year, month, day);
            }
          }

          // Geçerli bir tarih mi kontrol et
          if (date != null &&
              date.year >= currentYear &&
              date.year <= currentYear + 10 &&
              !dates.any((d) =>
                  d.year == date!.year &&
                  d.month == date.month &&
                  d.day == date.day)) {
            dates.add(date);
          }
        } catch (_) {
          // Geçersiz tarih, atla
        }
      }
    }

    // Tarihleri sırala
    dates.sort((a, b) => a.compareTo(b));
    return dates;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) {
      return '${diff.abs()} gün geçmiş';
    } else if (diff == 0) {
      return 'Bugün';
    } else if (diff == 1) {
      return 'Yarın';
    } else if (diff < 7) {
      return '$diff gün sonra';
    } else if (diff < 30) {
      final weeks = (diff / 7).floor();
      return '$weeks hafta sonra';
    } else if (diff < 365) {
      final months = (diff / 30).floor();
      return '$months ay sonra';
    } else {
      final years = (diff / 365).floor();
      return '$years yıl sonra';
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

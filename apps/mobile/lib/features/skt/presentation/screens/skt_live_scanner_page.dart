import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Canlı kamera ile SKT tarihini okuyan sayfa
class SktLiveScannerPage extends StatefulWidget {
  const SktLiveScannerPage({super.key});

  @override
  State<SktLiveScannerPage> createState() => _SktLiveScannerPageState();
}

class _SktLiveScannerPageState extends State<SktLiveScannerPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;

  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  bool _isCameraInitialized = false;

  // Algılanan tarihler
  List<DateTime> _detectedDates = [];
  DateTime? _selectedDate;

  // Scan alanı boyutları (ekranın ortasındaki alan)
  final double _scanAreaWidth = 280;
  final double _scanAreaHeight = 120;

  // Debounce için
  DateTime? _lastProcessTime;
  static const _processInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('Kamera bulunamadı');
        return;
      }

      // Arka kamerayı tercih et
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex == -1) _cameraIndex = 0;

      await _startCamera();
    } catch (e) {
      _showError('Kamera başlatılamadı: $e');
    }
  }

  Future<void> _startCamera() async {
    if (_cameras.isEmpty) return;

    final camera = _cameras[_cameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;

      // Kamera stream'ini başlat
      await _cameraController!.startImageStream(_processCameraImage);

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      _showError('Kamera başlatılamadı: $e');
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  void _processCameraImage(CameraImage image) async {
    // İşlem devam ediyorsa veya çok kısa süre geçtiyse atla
    if (_isProcessing) return;

    final now = DateTime.now();
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < _processInterval) {
      return;
    }

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (!mounted) {
        _isProcessing = false;
        return;
      }

      final text = recognizedText.text;
      if (text.isNotEmpty) {
        final dates = _extractDates(text);
        if (dates.isNotEmpty) {
          setState(() {
            _detectedDates = dates;
            // Otomatik olarak en yakın tarihi seç
            if (_selectedDate == null && dates.isNotEmpty) {
              _selectedDate = dates.first;
            }
          });
        }
      }
    } catch (e) {
      // OCR hatası - sessizce geç
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final orientations = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };

      var rotationCompensation =
          orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
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
      // USE BY formatı
      RegExp(r'USE\s*BY[:\s]*(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})',
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
            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              date = DateTime(year, month, day);
            }
          } else if (pattern.pattern.contains(r'(\d{4})') &&
              groups[2] == null) {
            // MM/YYYY format
            final month = int.parse(groups[0]!);
            final year = int.parse(groups[1]!);
            if (month >= 1 && month <= 12) {
              // Ayın son günü
              date = DateTime(year, month + 1, 0);
            }
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

          // Geçerli bir tarih mi kontrol et (son 1 yıl ile gelecek 10 yıl arası)
          if (date != null &&
              date.year >= currentYear - 1 &&
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

    // Tarihleri sırala (en yakın önce)
    dates.sort((a, b) => a.compareTo(b));
    return dates;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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

  void _switchCamera() async {
    if (_cameras.length < 2) return;

    await _stopCamera();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera();
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      final currentMode = _cameraController!.value.flashMode;
      final newMode =
          currentMode == FlashMode.torch ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() {});
    } catch (e) {
      // Flash desteklenmiyor olabilir
    }
  }

  void _confirmSelection() {
    if (_selectedDate != null) {
      Navigator.of(context).pop(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Canlı SKT Tarama'),
        actions: [
          if (_selectedDate != null)
            TextButton(
              onPressed: _confirmSelection,
              child: const Text(
                'Kullan',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Kamera önizleme
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 0,
                  height: _cameraController!.value.previewSize?.width ?? 0,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Tarama alanı overlay
          _buildScanOverlay(size),

          // Üst bilgi kartı
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _detectedDates.isNotEmpty
                        ? Icons.check_circle
                        : Icons.qr_code_scanner,
                    color:
                        _detectedDates.isNotEmpty ? Colors.green : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _detectedDates.isNotEmpty
                          ? '${_detectedDates.length} tarih algılandı'
                          : 'Ürün ambalajındaki tarihi çerçeveye hizalayın',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Algılanan tarihler listesi
          if (_detectedDates.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                height: 110,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _detectedDates.length,
                  itemBuilder: (context, index) {
                    final date = _detectedDates[index];
                    final isSelected = _selectedDate == date;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDate = date),
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.calendar_today,
                              color: isSelected ? Colors.white : colors.primary,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(date),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : colors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatRelativeDate(date),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : colors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Alt kontrol butonları
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Flash
                  _ControlButton(
                    icon: _cameraController?.value.flashMode == FlashMode.torch
                        ? Icons.flash_on
                        : Icons.flash_off,
                    label: 'Flaş',
                    onTap: _toggleFlash,
                  ),
                  // Onayla butonu
                  if (_selectedDate != null)
                    GestureDetector(
                      onTap: _confirmSelection,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(_selectedDate!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Kamera değiştir
                  if (_cameras.length > 1)
                    _ControlButton(
                      icon: Icons.cameraswitch,
                      label: 'Çevir',
                      onTap: _switchCamera,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay(Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2 - 60; // Biraz yukarı kaydır

    return CustomPaint(
      size: size,
      painter: _ScanOverlayPainter(
        scanRect: Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: _scanAreaWidth,
          height: _scanAreaHeight,
        ),
        borderColor: _detectedDates.isNotEmpty ? Colors.green : Colors.white,
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter({
    required this.scanRect,
    required this.borderColor,
  });

  final Rect scanRect;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Karanlık overlay (tarama alanı dışı)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Tarama alanı çerçevesi
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(16)),
      borderPaint,
    );

    // Köşe vurguları
    const cornerLength = 30.0;
    const cornerWidth = 4.0;
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerWidth
      ..strokeCap = StrokeCap.round;

    // Sol üst köşe
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top + cornerLength),
      Offset(scanRect.left, scanRect.top + 8),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left + 8, scanRect.top),
      Offset(scanRect.left + cornerLength, scanRect.top),
      cornerPaint,
    );

    // Sağ üst köşe
    canvas.drawLine(
      Offset(scanRect.right, scanRect.top + cornerLength),
      Offset(scanRect.right, scanRect.top + 8),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right - 8, scanRect.top),
      Offset(scanRect.right - cornerLength, scanRect.top),
      cornerPaint,
    );

    // Sol alt köşe
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom - cornerLength),
      Offset(scanRect.left, scanRect.bottom - 8),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left + 8, scanRect.bottom),
      Offset(scanRect.left + cornerLength, scanRect.bottom),
      cornerPaint,
    );

    // Sağ alt köşe
    canvas.drawLine(
      Offset(scanRect.right, scanRect.bottom - cornerLength),
      Offset(scanRect.right, scanRect.bottom - 8),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right - 8, scanRect.bottom),
      Offset(scanRect.right - cornerLength, scanRect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect ||
        oldDelegate.borderColor != borderColor;
  }
}

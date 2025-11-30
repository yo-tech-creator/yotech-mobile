import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _isProcessing = true;
        Navigator.of(context).pop(value);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Barkod Tara'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'torch',
                    backgroundColor: colors.primary,
                    onPressed: () => _controller.toggleTorch(),
                    child: ValueListenableBuilder<TorchState>(
                      valueListenable: _controller.torchState,
                      builder: (context, state, _) {
                        switch (state) {
                          case TorchState.off:
                            return const Icon(Icons.flash_off);
                          case TorchState.on:
                            return const Icon(Icons.flash_on);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton.small(
                    heroTag: 'switch-camera',
                    backgroundColor: colors.primary,
                    onPressed: () => _controller.switchCamera(),
                    child: const Icon(Icons.cameraswitch),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

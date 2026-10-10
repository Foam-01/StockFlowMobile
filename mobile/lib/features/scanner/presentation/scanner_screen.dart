import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n.dart';

/// Full-screen camera scanner. Pops with the scanned (or typed) barcode.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.title});

  /// Defaults to "Scan barcode" in the current language.
  final String? title;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done || code.trim().isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code.trim());
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final value = b.rawValue;
      if (value != null && value.isNotEmpty) return _finish(value);
    }
  }

  Future<void> _typeManually() async {
    await _controller.stop();
    if (!mounted) return;
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _ManualEntryDialog(),
    );
    if (code != null) {
      _finish(code);
    } else if (mounted) {
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -40)),
      width: 280,
      height: 180,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title ?? context.l10n.scanBarcode),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) => IconButton(
              tooltip: context.l10n.flashlight,
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
              ),
              onPressed: state.torchState == TorchState.unavailable
                  ? null
                  : _controller.toggleTorch,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            scanWindow: window,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                _CameraError(error: error, onTypeManually: _typeManually),
          ),
          IgnorePointer(child: CustomPaint(painter: _WindowPainter(window))),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              children: [
                Text(
                  context.l10n.pointCamera,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  key: const Key('manual_barcode'),
                  onPressed: _typeManually,
                  icon: const Icon(Icons.keyboard),
                  label: Text(context.l10n.typeBarcode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onTypeManually});

  final MobileScannerException error;
  final VoidCallback onTypeManually;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                denied
                    ? context.l10n.cameraPermission
                    : context.l10n.cameraUnavailable,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims everything except the scan window.
class _WindowPainter extends CustomPainter {
  _WindowPainter(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(window, const Radius.circular(16));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(r),
      ),
      Paint()..color = Colors.black54,
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_WindowPainter old) => old.window != window;
}

class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog();

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.trim().isNotEmpty) Navigator.pop(context, _text.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.enterBarcode),
      content: TextField(
        key: const Key('manual_barcode_field'),
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'e.g. 8859000500028'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.find)),
      ],
    );
  }
}

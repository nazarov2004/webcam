import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/signaling_protocol.dart';
import '../../../core/permissions/permission_service.dart';

/// Scans the LensCast Desktop pairing QR code and returns [QrPairingPayload].
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
  );
  bool _handled = false;
  bool _permissionGranted = false;
  bool _checkingPermission = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    setState(() {
      _checkingPermission = true;
      _error = null;
    });
    final status = await PermissionService.request(AppPermission.camera);
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _checkingPermission = false;
        _permissionGranted = false;
        _error = 'Camera permission is required to scan the QR code.';
      });
      return;
    }
    setState(() {
      _checkingPermission = false;
      _permissionGranted = true;
    });
    try {
      await _controller.start();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not start camera: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final payload = QrPairingPayload.tryDecode(raw);
      if (payload != null) {
        _handled = true;
        _controller.stop();
        if (mounted) context.pop(payload);
        return;
      } else {
        setState(() => _error = 'Not a valid LensCast Desktop QR code.');
      }
    }
  }

  Future<void> _pasteQrJson() async {
    final ctrl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste QR Payload'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '{"app":"lenscast",...}',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (raw == null || raw.isEmpty || !mounted) return;
    final payload = QrPairingPayload.tryDecode(raw);
    if (payload != null) {
      _handled = true;
      await _controller.stop();
      if (mounted) context.pop(payload);
    } else {
      setState(() => _error = 'Invalid LensCast QR payload.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Desktop QR Code'),
        actions: [
          if (_permissionGranted)
            IconButton(
              tooltip: 'Toggle Flash',
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flashlight_on_rounded),
            ),
          IconButton(
            tooltip: 'Paste QR Payload',
            onPressed: _pasteQrJson,
            icon: const Icon(Icons.paste_rounded),
          ),
        ],
      ),
      body: _checkingPermission
          ? const Center(child: CircularProgressIndicator())
          : !_permissionGranted
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_photography_rounded,
                            size: 56, color: AppColors.error),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error ?? 'Camera permission required.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          onPressed: _initScanner,
                          child: const Text('Grant Permission'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: PermissionService.openSettings,
                          child: const Text('Open App Settings'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        return Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(AppSpacing.pagePadding),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_rounded,
                                    size: 56, color: AppColors.error),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Camera unavailable: ${error.errorCode.name}',
                                  style: theme.textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  error.errorDetails?.message ??
                                      'Close other camera apps or use Paste QR / PIN.',
                                  style: theme.textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                FilledButton.icon(
                                  onPressed: _initScanner,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry Camera'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Center(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          border:
                              Border.all(color: AppColors.primary, width: 2.5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.pagePadding,
                      right: AppSpacing.pagePadding,
                      bottom: AppSpacing.xl,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.88),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Text(
                          _error ??
                              'Point your camera at the QR code shown in LensCast Desktop.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _error != null
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

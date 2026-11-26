import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/components.dart';

/// Renders a [MediaStream] with correct renderer lifecycle handling.
///
/// On non-mobile / web targets where no real stream exists, it shows a styled
/// placeholder rather than a broken Texture.
class CameraPreview extends StatefulWidget {
  const CameraPreview({
    super.key,
    required this.stream,
    this.mirror = false,
    this.rotateQuarterTurns = 0,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.overlay,
  });

  final MediaStream? stream;
  final bool mirror;
  final int rotateQuarterTurns;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? overlay;

  @override
  State<CameraPreview> createState() => _CameraPreviewState();
}

class _CameraPreviewState extends State<CameraPreview> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _ready = false;
  bool _initializing = false;
  MediaStream? _attached;

  @override
  void initState() {
    super.initState();
    // Lazy: only initialize the native renderer once there is a real stream.
    // Calling RTCVideoRenderer.initialize() eagerly (e.g. for an empty
    // dashboard preview) loads the WebRTC native library on the platform
    // thread and can stall startup / trigger an ANR on devices without a
    // camera. If a stream is already present at mount, attach now.
    if (widget.stream != null) _init();
  }

  Future<void> _init() async {
    if (_ready || _initializing) return;
    _initializing = true;
    try {
      await _renderer.initialize();
    } catch (e) {
      // Renderer init can fail on unsupported targets; stay in placeholder.
      _initializing = false;
      return;
    }
    if (!mounted) return;
    _initializing = false;
    setState(() => _ready = true);
    _attach();
  }

  void _attach() {
    final stream = widget.stream;
    if (stream == null) return;
    if (_attached == stream) return;
    _attached = stream;
    _renderer.srcObject = stream;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      if (widget.stream != null && !_ready) {
        _init();
      } else {
        _attach();
      }
    }
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasStream = widget.stream != null && _ready;
    Widget content;
    if (hasStream) {
      final fit = widget.fit == BoxFit.contain
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
      content = ClipRect(
        child: Transform.rotate(
          angle: widget.rotateQuarterTurns * 3.1415926535 / 2,
          child: Transform(
            alignment: Alignment.center,
            transform: widget.mirror
                ? (Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0))
                : Matrix4.identity(),
            child: RTCVideoView(
              _renderer,
              objectFit: fit,
              mirror: widget.mirror,
            ),
          ),
        ),
      );
    } else {
      content = widget.placeholder ??
          const ColoredBox(
            color: AppColors.surfaceAlt,
            child: Center(child: AppLoading(label: 'Starting camera...')),
          );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (widget.overlay != null) widget.overlay!,
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import 'pdf_viewer.dart';
import 'pdf_viewer_scroll_interaction_delegate.dart';

/// Provider for creating browser-style smooth scroll interaction delegate.
///
/// This delegate provides smooth scrolling behavior similar to web browsers,
/// using target position interpolation with easing curves.
class PdfViewerScrollInteractionDelegateSmoothProvider extends PdfViewerScrollInteractionDelegateProvider {
  /// Creates a [PdfViewerScrollInteractionDelegateSmoothProvider].
  ///
  /// [duration] is the animation duration for scrolling.
  /// [curve] is the easing curve for the animation.
  /// [scrollMultiplier] multiplies the scroll delta for faster/slower scrolling.
  const PdfViewerScrollInteractionDelegateSmoothProvider({
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.scrollMultiplier = 1.0,
    this.zoomDuration = const Duration(milliseconds: 200),
    this.zoomCurve = Curves.easeOut,
  });

  /// Animation duration for scrolling.
  final Duration duration;

  /// Easing curve for scroll animation.
  final Curve curve;

  /// Multiplier for scroll delta.
  final double scrollMultiplier;

  /// Animation duration for zooming.
  final Duration zoomDuration;

  /// Easing curve for zoom animation.
  final Curve zoomCurve;

  @override
  PdfViewerScrollInteractionDelegate create() => PdfViewerScrollInteractionDelegateSmooth(
        duration: duration,
        curve: curve,
        scrollMultiplier: scrollMultiplier,
        zoomDuration: zoomDuration,
        zoomCurve: zoomCurve,
      );

  @override
  bool operator ==(Object other) =>
      other is PdfViewerScrollInteractionDelegateSmoothProvider &&
      other.duration == duration &&
      other.curve == curve &&
      other.scrollMultiplier == scrollMultiplier &&
      other.zoomDuration == zoomDuration &&
      other.zoomCurve == zoomCurve;

  @override
  int get hashCode =>
      duration.hashCode ^ curve.hashCode ^ scrollMultiplier.hashCode ^ zoomDuration.hashCode ^ zoomCurve.hashCode;
}

/// Browser-style smooth scroll interaction delegate.
///
/// This delegate uses target position interpolation with easing curves,
/// similar to how web browsers handle smooth scrolling.
class PdfViewerScrollInteractionDelegateSmooth implements PdfViewerScrollInteractionDelegate {
  PdfViewerScrollInteractionDelegateSmooth({
    required this.duration,
    required this.curve,
    required this.scrollMultiplier,
    required this.zoomDuration,
    required this.zoomCurve,
  });

  /// Animation duration for scrolling.
  final Duration duration;

  /// Easing curve for scroll animation.
  final Curve curve;

  /// Multiplier for scroll delta.
  final double scrollMultiplier;

  /// Animation duration for zooming.
  final Duration zoomDuration;

  /// Easing curve for zoom animation.
  final Curve zoomCurve;

  PdfViewerController? _controller;
  AnimationController? _panController;
  AnimationController? _zoomController;
  Animation<Offset>? _panAnimation;
  Animation<double>? _zoomAnimation;

  Offset _targetOffset = Offset.zero;
  Offset _startOffset = Offset.zero;
  double _targetZoom = 1.0;
  double _startZoom = 1.0;
  Offset? _zoomFocalPoint;

  @override
  void init(PdfViewerController controller, TickerProvider tickerProvider) {
    _controller = controller;
    _panController = AnimationController(vsync: tickerProvider, duration: duration)
      ..addListener(_onPanAnimate);
    _zoomController = AnimationController(vsync: tickerProvider, duration: zoomDuration)
      ..addListener(_onZoomAnimate);
  }

  @override
  void dispose() {
    stop();
    _panController?.dispose();
    _zoomController?.dispose();
    _panController = null;
    _zoomController = null;
    _controller = null;
  }

  @override
  void stop() {
    _panController?.stop();
    _zoomController?.stop();
  }

  @override
  void pan(Offset delta) {
    if (_controller == null || _panController == null) return;

    // Stop zoom animation when panning
    _zoomController?.stop();

    final currentZoom = _controller!.currentZoom;
    final scaledDelta = delta * scrollMultiplier;

    // Get current position from controller
    final currentTranslation = _controller!.value.getTranslation();
    final currentOffset = Offset(currentTranslation.x, currentTranslation.y);

    // If animation is running, accumulate from target; otherwise from current
    if (_panController!.isAnimating) {
      _startOffset = Offset(
        _controller!.value.xZoomed,
        _controller!.value.yZoomed,
      );
      _targetOffset = _targetOffset + Offset(scaledDelta.dx * currentZoom, scaledDelta.dy * currentZoom);
    } else {
      _startOffset = currentOffset;
      _targetOffset = currentOffset + Offset(scaledDelta.dx * currentZoom, scaledDelta.dy * currentZoom);
    }

    _panAnimation = Tween<Offset>(
      begin: _startOffset,
      end: _targetOffset,
    ).animate(CurvedAnimation(parent: _panController!, curve: curve));

    _panController!.forward(from: 0.0);
  }

  @override
  void zoom(Offset focalPoint, double scaleDelta) {
    if (_controller == null || _zoomController == null) return;

    // Stop pan animation when zooming
    _panController?.stop();

    final currentZoom = _controller!.currentZoom;

    // If animation is running, accumulate from target; otherwise from current
    if (_zoomController!.isAnimating) {
      _startZoom = currentZoom;
      _targetZoom = (_targetZoom * scaleDelta).clamp(
        _controller!.minScale,
        _controller!.params.maxScale,
      );
    } else {
      _startZoom = currentZoom;
      _targetZoom = (currentZoom * scaleDelta).clamp(
        _controller!.minScale,
        _controller!.params.maxScale,
      );
    }

    _zoomFocalPoint = focalPoint;

    _zoomAnimation = Tween<double>(
      begin: _startZoom,
      end: _targetZoom,
    ).animate(CurvedAnimation(parent: _zoomController!, curve: zoomCurve));

    _zoomController!.forward(from: 0.0);
  }

  void _onPanAnimate() {
    if (_controller == null || _panAnimation == null) return;

    final offset = _panAnimation!.value;
    final m = _controller!.value.clone();
    m.setEntry(0, 3, offset.dx);
    m.setEntry(1, 3, offset.dy);
    _controller!.value = m;
  }

  void _onZoomAnimate() {
    if (_controller == null || _zoomAnimation == null || _zoomFocalPoint == null) return;

    final currentZoom = _controller!.currentZoom;
    final newZoom = _zoomAnimation!.value;

    if ((newZoom - currentZoom).abs() > 0.0001) {
      final position = _controller!.value.calcPosition(_controller!.viewSize);
      final focalPointDoc =
          (_zoomFocalPoint! - Offset(_controller!.value.xZoomed, _controller!.value.yZoomed)) / currentZoom;
      final newPosition = position + (focalPointDoc - position) * (1 - currentZoom / newZoom);
      _controller!.value = _controller!.calcMatrixFor(newPosition, zoom: newZoom);
    }
  }
}

import 'package:flutter/material.dart';

import 'pdf_viewer.dart';
import 'pdf_viewer_scroll_interaction_delegate.dart';

/// Provider for creating instant scroll interaction delegate.
///
/// The instant delegate applies scroll and zoom changes immediately
/// without any animation or physics simulation.
class PdfViewerScrollInteractionDelegateInstantProvider extends PdfViewerScrollInteractionDelegateProvider {
  /// Creates a [PdfViewerScrollInteractionDelegateInstantProvider].
  const PdfViewerScrollInteractionDelegateInstantProvider();

  @override
  PdfViewerScrollInteractionDelegate create() => PdfViewerScrollInteractionDelegateInstant();
}

/// Instant scroll interaction delegate.
///
/// This delegate applies scroll and zoom changes immediately without
/// any animation or physics simulation.
class PdfViewerScrollInteractionDelegateInstant implements PdfViewerScrollInteractionDelegate {
  PdfViewerController? _controller;

  @override
  void init(PdfViewerController controller, TickerProvider tickerProvider) {
    _controller = controller;
  }

  @override
  void dispose() {
    _controller = null;
  }

  @override
  void stop() {
    // Nothing to stop for instant delegate
  }

  @override
  void pan(Offset delta) {
    if (_controller == null) return;
    final m = _controller!.value.clone();
    m.translateByDouble(delta.dx, delta.dy, 0, 1);
    _controller!.value = m;
  }

  @override
  void zoom(Offset focalPoint, double scaleDelta) {
    if (_controller == null) return;
    final currentZoom = _controller!.currentZoom;
    final newZoom = (currentZoom * scaleDelta).clamp(
      _controller!.minScale,
      _controller!.params.maxScale,
    );
    final position = _controller!.value.calcPosition(_controller!.viewSize);
    final focalPointDoc =
        (focalPoint - Offset(_controller!.value.xZoomed, _controller!.value.yZoomed)) / currentZoom;
    final newPosition = position + (focalPointDoc - position) * (1 - currentZoom / newZoom);
    _controller!.value = _controller!.calcMatrixFor(newPosition, zoom: newZoom);
  }
}

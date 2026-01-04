import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import 'pdf_viewer.dart';
import 'pdf_viewer_scroll_interaction_delegate.dart';

/// Provider for creating physics-based scroll interaction delegate.
///
/// The physics delegate applies scroll and zoom changes with smooth
/// physics-based animations.
class PdfViewerScrollInteractionDelegatePhysicsProvider extends PdfViewerScrollInteractionDelegateProvider {
  /// Creates a [PdfViewerScrollInteractionDelegatePhysicsProvider].
  ///
  /// [panFriction] is the friction coefficient for pan deceleration.
  /// [zoomFriction] is the friction coefficient for zoom deceleration.
  const PdfViewerScrollInteractionDelegatePhysicsProvider({
    this.panFriction = 0.015,
    this.zoomFriction = 0.02,
  });

  /// Friction coefficient for pan deceleration.
  final double panFriction;

  /// Friction coefficient for zoom deceleration.
  final double zoomFriction;

  @override
  PdfViewerScrollInteractionDelegate create() => PdfViewerScrollInteractionDelegatePhysics(
        panFriction: panFriction,
        zoomFriction: zoomFriction,
      );

  @override
  bool operator ==(Object other) =>
      other is PdfViewerScrollInteractionDelegatePhysicsProvider &&
      other.panFriction == panFriction &&
      other.zoomFriction == zoomFriction;

  @override
  int get hashCode => panFriction.hashCode ^ zoomFriction.hashCode;
}

/// Physics-based scroll interaction delegate.
///
/// This delegate applies scroll and zoom changes with smooth
/// physics-based animations using friction simulation.
class PdfViewerScrollInteractionDelegatePhysics implements PdfViewerScrollInteractionDelegate {
  PdfViewerScrollInteractionDelegatePhysics({
    required this.panFriction,
    required this.zoomFriction,
  });

  /// Friction coefficient for pan deceleration.
  final double panFriction;

  /// Friction coefficient for zoom deceleration.
  final double zoomFriction;

  PdfViewerController? _controller;
  Ticker? _panTicker;
  Ticker? _zoomTicker;

  FrictionSimulation? _panSimulationX;
  FrictionSimulation? _panSimulationY;
  FrictionSimulation? _zoomSimulation;
  Offset? _zoomFocalPoint;
  Duration? _lastPanTime;
  Duration? _lastZoomTime;

  @override
  void init(PdfViewerController controller, TickerProvider tickerProvider) {
    _controller = controller;
    _panTicker = tickerProvider.createTicker(_onPanTick);
    _zoomTicker = tickerProvider.createTicker(_onZoomTick);
  }

  @override
  void dispose() {
    stop();
    _panTicker?.dispose();
    _zoomTicker?.dispose();
    _panTicker = null;
    _zoomTicker = null;
    _controller = null;
  }

  @override
  void stop() {
    _panTicker?.stop();
    _zoomTicker?.stop();
    _panSimulationX = null;
    _panSimulationY = null;
    _zoomSimulation = null;
    _lastPanTime = null;
    _lastZoomTime = null;
  }

  @override
  void pan(Offset delta) {
    if (_controller == null) return;

    // Stop zoom animation if running
    _zoomTicker?.stop();
    _zoomSimulation = null;

    final currentZoom = _controller!.currentZoom;
    final velocityX = delta.dx * currentZoom * 60; // Scale velocity by frame rate
    final velocityY = delta.dy * currentZoom * 60;

    _panSimulationX = FrictionSimulation(
      panFriction,
      _controller!.value.xZoomed,
      velocityX,
    );
    _panSimulationY = FrictionSimulation(
      panFriction,
      _controller!.value.yZoomed,
      velocityY,
    );

    _lastPanTime = null;
    if (!_panTicker!.isActive) {
      _panTicker!.start();
    }
  }

  @override
  void zoom(Offset focalPoint, double scaleDelta) {
    if (_controller == null) return;

    // Stop pan animation if running
    _panTicker?.stop();
    _panSimulationX = null;
    _panSimulationY = null;

    final currentZoom = _controller!.currentZoom;
    final targetZoom = (currentZoom * scaleDelta).clamp(
      _controller!.minScale,
      _controller!.params.maxScale,
    );

    final velocity = (targetZoom - currentZoom) * 60; // Scale velocity by frame rate

    _zoomSimulation = FrictionSimulation(
      zoomFriction,
      currentZoom,
      velocity,
    );
    _zoomFocalPoint = focalPoint;

    _lastZoomTime = null;
    if (!_zoomTicker!.isActive) {
      _zoomTicker!.start();
    }
  }

  void _onPanTick(Duration elapsed) {
    if (_controller == null || _panSimulationX == null || _panSimulationY == null) {
      _panTicker?.stop();
      return;
    }

    _lastPanTime ??= elapsed;
    final t = (elapsed - _lastPanTime!).inMicroseconds / 1000000.0;

    final x = _panSimulationX!.x(t);
    final y = _panSimulationY!.x(t);

    final m = _controller!.value.clone();
    m.setEntry(0, 3, x);
    m.setEntry(1, 3, y);
    _controller!.value = m;

    // Stop if simulation is done
    if (_panSimulationX!.isDone(t) && _panSimulationY!.isDone(t)) {
      _panTicker?.stop();
      _panSimulationX = null;
      _panSimulationY = null;
      _lastPanTime = null;
    }
  }

  void _onZoomTick(Duration elapsed) {
    if (_controller == null || _zoomSimulation == null || _zoomFocalPoint == null) {
      _zoomTicker?.stop();
      return;
    }

    _lastZoomTime ??= elapsed;
    final t = (elapsed - _lastZoomTime!).inMicroseconds / 1000000.0;

    final currentZoom = _controller!.currentZoom;
    var newZoom = _zoomSimulation!.x(t);
    newZoom = newZoom.clamp(_controller!.minScale, _controller!.params.maxScale);

    if ((newZoom - currentZoom).abs() > 0.0001) {
      final position = _controller!.value.calcPosition(_controller!.viewSize);
      final focalPointDoc =
          (_zoomFocalPoint! - Offset(_controller!.value.xZoomed, _controller!.value.yZoomed)) / currentZoom;
      final newPosition = position + (focalPointDoc - position) * (1 - currentZoom / newZoom);
      _controller!.value = _controller!.calcMatrixFor(newPosition, zoom: newZoom);
    }

    // Stop if simulation is done
    if (_zoomSimulation!.isDone(t)) {
      _zoomTicker?.stop();
      _zoomSimulation = null;
      _zoomFocalPoint = null;
      _lastZoomTime = null;
    }
  }
}

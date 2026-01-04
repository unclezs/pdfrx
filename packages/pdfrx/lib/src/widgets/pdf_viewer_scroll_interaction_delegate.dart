import 'package:flutter/material.dart';

import 'pdf_viewer.dart';

/// Provider for creating [PdfViewerScrollInteractionDelegate] instances.
///
/// This is used to provide a scroll interaction delegate for the PDF viewer.
/// Delegate should be created in the provider's [create] method.
abstract class PdfViewerScrollInteractionDelegateProvider {
  /// Creates a [PdfViewerScrollInteractionDelegateProvider].
  const PdfViewerScrollInteractionDelegateProvider();

  /// Creates a [PdfViewerScrollInteractionDelegate].
  PdfViewerScrollInteractionDelegate create();

  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Delegate for handling scroll and zoom interactions in the PDF viewer.
///
/// This abstract class defines the interface for scroll interaction handling,
/// allowing different implementations (instant, physics-based, etc.).
abstract class PdfViewerScrollInteractionDelegate {
  /// Initializes the delegate with the controller and ticker provider.
  void init(PdfViewerController controller, TickerProvider tickerProvider);

  /// Disposes resources used by the delegate.
  void dispose();

  /// Stops any ongoing animations.
  void stop();

  /// Handles pan (scroll) requests.
  ///
  /// [delta] is the scroll delta in document coordinates.
  void pan(Offset delta);

  /// Handles zoom requests.
  ///
  /// [focalPoint] is the focal point for zooming in local coordinates.
  /// [scaleDelta] is the change in scale (e.g., 1.1 means 10% zoom in).
  void zoom(Offset focalPoint, double scaleDelta);
}

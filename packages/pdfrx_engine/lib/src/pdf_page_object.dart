import 'dart:typed_data';

import 'pdf_image.dart';
import 'pdf_rect.dart';

/// Type of page object in a PDF page.
enum PdfPageObjectType {
  /// Unknown object type.
  unknown(0),

  /// Text object.
  text(1),

  /// Path object (vector graphics).
  path(2),

  /// Image object.
  image(3),

  /// Shading object.
  shading(4),

  /// Form XObject (can contain nested objects).
  form(5);

  const PdfPageObjectType(this.value);

  /// The PDFium constant value for this type.
  final int value;

  /// Create a [PdfPageObjectType] from a PDFium constant value.
  static PdfPageObjectType fromValue(int value) {
    return PdfPageObjectType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PdfPageObjectType.unknown,
    );
  }
}

/// Base class for page objects in a PDF page.
///
/// Use [PdfPage.loadObjects] to get page objects.
abstract class PdfPageObject {
  /// Type of the page object.
  PdfPageObjectType get type;

  /// Bounding box of the page object in PDF page coordinates.
  PdfRect get bounds;
}

/// Image object in a PDF page.
///
/// Provides methods to extract image data from the PDF.
abstract class PdfImageObject extends PdfPageObject {
  @override
  PdfPageObjectType get type => PdfPageObjectType.image;

  /// Image width in pixels.
  int get width;

  /// Image height in pixels.
  int get height;

  /// Horizontal DPI (dots per inch).
  double get horizontalDpi;

  /// Vertical DPI (dots per inch).
  double get verticalDpi;

  /// Bits per pixel.
  int get bitsPerPixel;

  /// Colorspace of the image.
  PdfImageColorspace get colorspace;

  /// Get the rendered bitmap of the image.
  ///
  /// This method renders the image considering the image mask and transformation matrix.
  /// Returns null if the rendering fails.
  Future<PdfImage?> getRenderedBitmap();

  /// Get the raw bitmap of the image.
  ///
  /// This method returns the bitmap without considering the image mask.
  /// Returns null if the extraction fails.
  Future<PdfImage?> getBitmap();

  /// Get the decoded image data.
  ///
  /// Returns the uncompressed image data (raw pixel data after decompression).
  /// Returns null if the extraction fails.
  Future<Uint8List?> getDecodedData();
}

/// Colorspace types for PDF images.
enum PdfImageColorspace {
  /// Unknown colorspace.
  unknown(0),

  /// Device Gray (1 component).
  deviceGray(1),

  /// Device RGB (3 components).
  deviceRgb(2),

  /// Device CMYK (4 components).
  deviceCmyk(3),

  /// CalGray.
  calGray(4),

  /// CalRGB.
  calRgb(5),

  /// Lab.
  lab(6),

  /// ICCBased.
  iccBased(7),

  /// Separation.
  separation(8),

  /// DeviceN.
  deviceN(9),

  /// Indexed.
  indexed(10),

  /// Pattern.
  pattern(11);

  const PdfImageColorspace(this.value);

  /// The PDFium constant value for this colorspace.
  final int value;

  /// Create a [PdfImageColorspace] from a PDFium constant value.
  static PdfImageColorspace fromValue(int value) {
    return PdfImageColorspace.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PdfImageColorspace.unknown,
    );
  }
}

/// Result of loading page objects.
class PdfPageObjects {
  const PdfPageObjects({
    required this.objects,
  });

  /// All page objects.
  final List<PdfPageObject> objects;

  /// Get all image objects.
  List<PdfImageObject> get imageObjects =>
      objects.whereType<PdfImageObject>().toList();

  /// Get all text objects (type only, no content).
  List<PdfPageObject> get textObjects =>
      objects.where((o) => o.type == PdfPageObjectType.text).toList();
}

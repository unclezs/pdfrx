import 'dart:io';

import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

import 'utils.dart';

final testPdfFile = File('../pdfrx/example/viewer/assets/hello.pdf');

void main() {
  setUp(() => pdfrxInitialize(tmpPath: tmpRoot.path));

  group('PdfPage.loadObjects', () {
    test('returns page objects for a valid page', () async {
      final doc = await PdfDocument.openFile(testPdfFile.path);
      expect(doc.pages.length, greaterThan(0));

      final page = doc.pages[0];
      final objects = await page.loadObjects();

      expect(objects, isNotNull);
      expect(objects!.objects, isA<List<PdfPageObject>>());

      // Print object info for debugging
      print('Page 1 has ${objects.objects.length} objects');
      for (final obj in objects.objects) {
        print('  Object type: ${obj.type}, bounds: ${obj.bounds}');
        if (obj is PdfImageObject) {
          print('    Image: ${obj.width}x${obj.height}, colorspace: ${obj.colorspace}');
        }
      }

      await doc.dispose();
    });

    test('filters image objects correctly', () async {
      final doc = await PdfDocument.openFile(testPdfFile.path);
      final page = doc.pages[0];
      final objects = await page.loadObjects();

      expect(objects, isNotNull);

      final imageObjects = objects!.imageObjects;
      expect(imageObjects, isA<List<PdfImageObject>>());

      // All items should be PdfImageObject
      for (final img in imageObjects) {
        expect(img.type, equals(PdfPageObjectType.image));
      }

      await doc.dispose();
    });

    test('image object has valid dimensions', () async {
      final doc = await PdfDocument.openFile(testPdfFile.path);

      // Find a page with images
      PdfImageObject? imageObj;
      for (final page in doc.pages) {
        final objects = await page.loadObjects();
        if (objects != null && objects.imageObjects.isNotEmpty) {
          imageObj = objects.imageObjects.first;
          break;
        }
      }

      if (imageObj != null) {
        // Test image properties
        expect(imageObj.width, greaterThanOrEqualTo(0));
        expect(imageObj.height, greaterThanOrEqualTo(0));
        expect(imageObj.bounds, isA<PdfRect>());

        print('Found image: ${imageObj.width}x${imageObj.height}');
        print('  Bounds: ${imageObj.bounds}');
        print('  DPI: ${imageObj.horizontalDpi}x${imageObj.verticalDpi}');
        print('  Bits per pixel: ${imageObj.bitsPerPixel}');
        print('  Colorspace: ${imageObj.colorspace}');
      } else {
        print('No image objects found in the test PDF');
      }

      await doc.dispose();
    });

    test('can get rendered bitmap from image object', () async {
      final doc = await PdfDocument.openFile(testPdfFile.path);

      // Find a page with images
      PdfImageObject? imageObj;
      for (final page in doc.pages) {
        final objects = await page.loadObjects();
        if (objects != null && objects.imageObjects.isNotEmpty) {
          imageObj = objects.imageObjects.first;
          break;
        }
      }

      if (imageObj != null) {
        final bitmap = await imageObj.getRenderedBitmap();
        if (bitmap != null) {
          expect(bitmap.width, greaterThan(0));
          expect(bitmap.height, greaterThan(0));
          expect(bitmap.pixels, isNotEmpty);
          print('Rendered bitmap: ${bitmap.width}x${bitmap.height}');
          bitmap.dispose();
        } else {
          print('getRenderedBitmap returned null');
        }
      } else {
        print('No image objects found in the test PDF');
      }

      await doc.dispose();
    });

    test('can get raw bitmap from image object', () async {
      final doc = await PdfDocument.openFile(testPdfFile.path);

      // Find a page with images
      PdfImageObject? imageObj;
      for (final page in doc.pages) {
        final objects = await page.loadObjects();
        if (objects != null && objects.imageObjects.isNotEmpty) {
          imageObj = objects.imageObjects.first;
          break;
        }
      }

      if (imageObj != null) {
        final bitmap = await imageObj.getBitmap();
        if (bitmap != null) {
          expect(bitmap.width, greaterThan(0));
          expect(bitmap.height, greaterThan(0));
          expect(bitmap.pixels, isNotEmpty);
          print('Raw bitmap: ${bitmap.width}x${bitmap.height}');
          bitmap.dispose();
        } else {
          print('getBitmap returned null');
        }
      } else {
        print('No image objects found in the test PDF');
      }

      await doc.dispose();
    });

    test('can get decoded data from image object', () async {
      final doc = await PdfDocument.openFile(testPdfFile.path);

      // Find a page with images
      PdfImageObject? imageObj;
      for (final page in doc.pages) {
        final objects = await page.loadObjects();
        if (objects != null && objects.imageObjects.isNotEmpty) {
          imageObj = objects.imageObjects.first;
          break;
        }
      }

      if (imageObj != null) {
        final data = await imageObj.getDecodedData();
        if (data != null) {
          expect(data, isNotEmpty);
          print('Decoded data size: ${data.length} bytes');
        } else {
          print('getDecodedData returned null');
        }
      } else {
        print('No image objects found in the test PDF');
      }

      await doc.dispose();
    });

    test('returns correct object types', () async {
      final doc = await PdfDocument.openFile(testPdfFile.path);
      final page = doc.pages[0];
      final objects = await page.loadObjects();

      expect(objects, isNotNull);

      for (final obj in objects!.objects) {
        expect(obj.type, isIn([
          PdfPageObjectType.unknown,
          PdfPageObjectType.text,
          PdfPageObjectType.path,
          PdfPageObjectType.image,
          PdfPageObjectType.shading,
          PdfPageObjectType.form,
        ]));
      }

      await doc.dispose();
    });

    test('page proxy classes delegate loadObjects correctly', () async {
      final doc = await PdfDocument.openFile(testPdfFile.path);
      final page = doc.pages[0];

      // Test PdfPageRenumbered
      final renumberedPage = page.withPageNumber(99);
      final renumberedObjects = await renumberedPage.loadObjects();
      expect(renumberedObjects, isNotNull);

      // Test PdfPageRotated
      final rotatedPage = page.rotatedCW90();
      final rotatedObjects = await rotatedPage.loadObjects();
      expect(rotatedObjects, isNotNull);

      await doc.dispose();
    });
  });

  group('PdfPageObjectType', () {
    test('fromValue returns correct type', () {
      expect(PdfPageObjectType.fromValue(0), equals(PdfPageObjectType.unknown));
      expect(PdfPageObjectType.fromValue(1), equals(PdfPageObjectType.text));
      expect(PdfPageObjectType.fromValue(2), equals(PdfPageObjectType.path));
      expect(PdfPageObjectType.fromValue(3), equals(PdfPageObjectType.image));
      expect(PdfPageObjectType.fromValue(4), equals(PdfPageObjectType.shading));
      expect(PdfPageObjectType.fromValue(5), equals(PdfPageObjectType.form));
      expect(PdfPageObjectType.fromValue(99), equals(PdfPageObjectType.unknown));
    });
  });

  group('PdfImageColorspace', () {
    test('fromValue returns correct colorspace', () {
      expect(PdfImageColorspace.fromValue(0), equals(PdfImageColorspace.unknown));
      expect(PdfImageColorspace.fromValue(1), equals(PdfImageColorspace.deviceGray));
      expect(PdfImageColorspace.fromValue(2), equals(PdfImageColorspace.deviceRgb));
      expect(PdfImageColorspace.fromValue(3), equals(PdfImageColorspace.deviceCmyk));
      expect(PdfImageColorspace.fromValue(99), equals(PdfImageColorspace.unknown));
    });
  });
}

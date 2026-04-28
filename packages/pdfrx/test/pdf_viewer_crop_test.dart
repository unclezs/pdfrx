import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

final testPdfFile = File('example/viewer/assets/hello.pdf');
final binding = TestWidgetsFlutterBinding.ensureInitialized();

void main() {
  test('PdfViewerParams normalizes page crop rectangles', () {
    final page = _FakePdfPage(width: 100, height: 200);

    expect(
      PdfViewerParams(pageCropRectProvider: (_) => const Rect.fromLTRB(-10, 20, 90, 240)).getPageCropRect(page),
      const Rect.fromLTRB(0, 20, 90, 200),
    );
    expect(
      PdfViewerParams(pageCropRectProvider: (_) => const Rect.fromLTRB(80, 20, 10, 180)).getPageCropRect(page),
      const Rect.fromLTWH(0, 0, 100, 200),
    );
    expect(const PdfViewerParams().getPageVisibleSize(page), const Size(100, 200));
  });

  testWidgets('PdfViewer applies page crop to layout and coordinate mapping', (tester) async {
    if ((Platform.environment['PDFIUM_PATH'] ?? '').isEmpty) {
      markTestSkipped('Set PDFIUM_PATH to run PdfViewer crop rendering test.');
      return;
    }

    try {
      await pdfrxInitialize();
    } catch (e) {
      markTestSkipped('PDFium is not available in this environment: $e');
      return;
    }

    await binding.setSurfaceSize(const Size(800, 1000));

    final controller = PdfViewerController();
    Rect? cropFor(PdfPage page) => Rect.fromLTRB(10, 20, page.width - 30, page.height - 40);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: PdfViewer.file(
            testPdfFile.path,
            controller: controller,
            params: PdfViewerParams(margin: 0, pageCropRectProvider: cropFor),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(controller.isReady, isTrue);

    final page = controller.document.pages.first;
    final crop = cropFor(page)!;
    final pageRect = controller.layout.pageLayouts.first;

    expect(pageRect.size.width, closeTo(crop.width, 0.01));
    expect(pageRect.size.height, closeTo(crop.height, 0.01));

    final visiblePoint = pageRect.topLeft + const Offset(5, 7);
    final hit = controller.getPdfPageHitTestResult(visiblePoint, useDocumentLayoutCoordinates: true);
    expect(hit, isNotNull);

    final expectedPoint = Offset(crop.left + 5, crop.top + 7).toPdfPoint(page: page);
    expect(hit!.offset.x, closeTo(expectedPoint.x, 0.01));
    expect(hit.offset.y, closeTo(expectedPoint.y, 0.01));

    final sourceRect = Rect.fromLTWH(crop.left + 6, crop.top + 8, 20, 30);
    final mappedRect = controller.calcRectForRectInsidePage(
      pageNumber: page.pageNumber,
      rect: sourceRect.toPdfRect(page: page),
    );

    expect(mappedRect.left, closeTo(pageRect.left + 6, 0.01));
    expect(mappedRect.top, closeTo(pageRect.top + 8, 0.01));
    expect(mappedRect.width, closeTo(20, 0.01));
    expect(mappedRect.height, closeTo(30, 0.01));
  });
}

class _FakePdfPage implements PdfPage {
  _FakePdfPage({required this.width, required this.height});

  @override
  final double width;

  @override
  final double height;

  @override
  int get pageNumber => 1;

  @override
  PdfPageRotation get rotation => PdfPageRotation.none;

  @override
  bool get isLoaded => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

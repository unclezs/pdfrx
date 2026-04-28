import 'package:flutter/material.dart';

import '../../pdfrx.dart';

typedef PdfPageLinkWrapperWidgetBuilder = Widget Function(Widget child);

/// A widget that displays links on a page.
class PdfPageLinksOverlay extends StatefulWidget {
  const PdfPageLinksOverlay({
    required this.page,
    required this.pageRect,
    required this.params,
    this.wrapperBuilder,
    super.key,
  });

  final PdfPage page;
  final Rect pageRect;
  final PdfViewerParams params;

  /// Currently, the handler is used to wrap the actual link widget with [Listener] not to absorb wheel-events.
  final PdfPageLinkWrapperWidgetBuilder? wrapperBuilder;

  @override
  State<PdfPageLinksOverlay> createState() => _PdfPageLinksOverlayState();
}

class _PdfPageLinksOverlayState extends State<PdfPageLinksOverlay> {
  List<PdfLink>? links;

  @override
  void initState() {
    super.initState();
    _initLinks();
  }

  @override
  void didUpdateWidget(covariant PdfPageLinksOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != oldWidget.page) {
      _initLinks();
    }
  }

  Future<void> _initLinks() async {
    links = await widget.page.loadLinks();
    if (mounted) {
      setState(() {});
    }
  }

  Rect _linkRectToCroppedPageRect(PdfRect rect) {
    final cropRect = widget.params.getPageCropRect(widget.page);
    final pageRect = rect.toRect(page: widget.page);
    final sx = widget.pageRect.width / cropRect.width;
    final sy = widget.pageRect.height / cropRect.height;
    final mapped = Rect.fromLTRB(
      (pageRect.left - cropRect.left) * sx,
      (pageRect.top - cropRect.top) * sy,
      (pageRect.right - cropRect.left) * sx,
      (pageRect.bottom - cropRect.top) * sy,
    );
    return mapped.intersect(
      Rect.fromLTWH(0, 0, widget.pageRect.width, widget.pageRect.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (links == null) return const SizedBox();

    final linkWidgets = <Widget>[];
    for (final link in links!) {
      for (final rect in link.rects) {
        final rectLink = _linkRectToCroppedPageRect(rect);
        if (rectLink.isEmpty) {
          continue;
        }
        final linkWidget = widget.params.linkWidgetBuilder!(
          context,
          link,
          rectLink.size,
        );
        if (linkWidget != null) {
          linkWidgets.add(
            Positioned(
              left: rectLink.left,
              top: rectLink.top,
              width: rectLink.width,
              height: rectLink.height,
              child: widget.wrapperBuilder?.call(linkWidget) ?? linkWidget,
            ),
          );
        }
      }
    }

    return Positioned(
      left: widget.pageRect.left,
      top: widget.pageRect.top,
      width: widget.pageRect.width,
      height: widget.pageRect.height,
      child: Stack(children: linkWidgets),
    );
  }
}

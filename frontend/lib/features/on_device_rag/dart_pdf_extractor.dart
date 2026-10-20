import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Pure-Dart PDF text extraction: the offline fallback.
///
/// It reads text-only PDFs on the device with no network at all. Scanned
/// pages and odd encodings come out worse than the server parser, so the
/// caller marks the result as a draft and re-extracts it later.
class DartPdfExtractor {
  /// The text of every page, in order. Throws when the file cannot be read.
  List<String> pages(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      return [
        for (var index = 0; index < document.pages.count; index++)
          extractor.extractText(startPageIndex: index, endPageIndex: index),
      ];
    } finally {
      document.dispose();
    }
  }
}

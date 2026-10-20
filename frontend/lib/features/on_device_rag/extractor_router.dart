import 'dart:typed_data';

import '../../core/api/api_client.dart';
import 'dart_pdf_extractor.dart';

/// The pages of a freshly extracted PDF.
class Extraction {
  const Extraction({
    required this.title,
    required this.pages,
    required this.draft,
  });

  final String title;
  final List<String> pages;

  /// True when the on-device fallback did the work: good enough to read and
  /// search now, re-extracted with the better server parser when online.
  final bool draft;
}

/// Server extraction first, on-device fallback second.
///
/// While offline (or when the server is unreachable) the device extracts
/// the PDF itself, so uploads still work. The draft flag is what makes the
/// app re-run the good parser later instead of losing quality silently.
final extractorRouter = ExtractorRouter();

class ExtractorRouter {
  ExtractorRouter([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;
  final DartPdfExtractor _dart = DartPdfExtractor();

  static const _timeout = Duration(seconds: 30);

  Future<Extraction> extract(String filename, Uint8List bytes) async {
    try {
      final result = await extractOnServer(filename, bytes);
      return Extraction(title: result.title, pages: result.pages, draft: false);
    } catch (_) {
      return Extraction(
        title: titleFrom(filename),
        pages: _dart.pages(bytes),
        draft: true,
      );
    }
  }

  /// The server parser only. Used for re-extracting drafts once online.
  Future<Extraction> extractOnServer(String filename, Uint8List bytes) async {
    final data = await _api
        .extractPdf(filename, bytes)
        .timeout(_timeout) as Map<String, dynamic>;
    return Extraction(
      title: data['title']?.toString() ?? titleFrom(filename),
      pages: [
        for (final page in data['pages'] as List? ?? const [])
          if (page is Map<String, dynamic>) page['text']?.toString() ?? '',
      ],
      draft: false,
    );
  }

  static String titleFrom(String filename) {
    final name = filename.split('/').last;
    final dot = name.lastIndexOf('.');
    final title = dot > 0 ? name.substring(0, dot) : name;
    return title.trim().isEmpty ? 'Untitled' : title.trim();
  }
}

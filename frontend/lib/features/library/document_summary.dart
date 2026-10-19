import 'document_info.dart';

String formatSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

String documentSummary(DocumentInfo document) {
  final parts = <String>[];
  if (document.pages > 0) parts.add('${document.pages} pages');
  if (document.chunks > 0) parts.add('${document.chunks} passages');
  if (document.sizeBytes > 0) parts.add(formatSize(document.sizeBytes));
  return parts.isEmpty ? 'Preparing document…' : parts.join('  ·  ');
}

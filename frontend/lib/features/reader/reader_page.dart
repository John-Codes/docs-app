import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import 'pdf_frame.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({
    super.key,
    required this.docId,
    required this.title,
    this.initialPage,
  });

  final String docId;
  final String title;
  final int? initialPage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: PdfFrame(
        url: ApiClient().documentFileUrl(docId, page: initialPage),
      ),
    );
  }
}

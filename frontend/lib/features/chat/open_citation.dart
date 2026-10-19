import 'package:flutter/material.dart';

import '../reader/reader_page.dart';
import 'chat_source.dart';

/// Opens the document at the page a citation points to.
void openCitation(BuildContext context, ChatSource source) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ReaderPage(
        docId: source.docId,
        title: source.docTitle,
        initialPage: source.page,
      ),
    ),
  );
}
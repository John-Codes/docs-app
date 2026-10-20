import 'package:flutter/material.dart';

import '../on_device_rag/pdf_blob_store.dart';
import 'pdf_frame.dart';

/// Opens a document from this device: the PDF is stored in the browser,
/// so the reader works with no server and no network.
class ReaderPage extends StatefulWidget {
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
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final url = await pdfBlobStore.urlFor(widget.docId);
      if (!mounted) {
        if (url != null) pdfBlobStore.revoke(url);
        return;
      }
      setState(() {
        _url = url;
        _failed = url == null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    final url = _url;
    if (url != null) pdfBlobStore.revoke(url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final url = _url;
    if (url != null) {
      final page = widget.initialPage;
      final suffix = page != null && page > 0 ? '#page=$page' : '';
      return PdfFrame(url: '$url$suffix');
    }
    return Center(
      child: _failed
          ? const Text('This document is no longer stored on this device.')
          : const CircularProgressIndicator(),
    );
  }
}

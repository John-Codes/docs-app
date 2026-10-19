import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final _registered = <String>{};

/// Renders a PDF with the browser's native viewer inside an iframe.
class PdfFrame extends StatelessWidget {
  const PdfFrame({super.key, required this.url});

  final String url;

  String get _viewType => 'pdf-frame-${url.hashCode}';

  void _registerFactory() {
    if (_registered.contains(_viewType)) return;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..title = 'Document'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
    _registered.add(_viewType);
  }

  @override
  Widget build(BuildContext context) {
    _registerFactory();
    return HtmlElementView(viewType: _viewType);
  }
}

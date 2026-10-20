import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

import 'document_catalog.dart';
import 'document_ingest.dart';

/// The service manual that ships inside the app, so the library has a
/// document to read and ask about before anyone uploads one.
final bundledDocument = BundledDocument();

class BundledDocument {
  static const _seededKey = 'on_device_rag_bundled_seeded_v1';

  static const id = 'bundled-hardrock-field-equipment-service-manual';
  static const title = 'HardRock Field Equipment Service Manual';
  static const filename = 'HardRock_Field_Equipment_Service_Manual_Uniform.pdf';
  static const asset = 'assets/documents/$filename';

  /// Stores and indexes the bundled PDF once, when search is ready. Never
  /// throws, and never comes back after the user deletes it.
  Future<void> seed() async {
    try {
      if (web.window.localStorage.getItem(_seededKey) != null) return;

      if (documentCatalog.find(id) == null) {
        final data = await rootBundle.load(asset);
        await documentIngest.add(
          id: id,
          title: title,
          filename: filename,
          bytes: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        );
      }
      web.window.localStorage.setItem(_seededKey, '1');
    } catch (_) {
      // A convenience only: without it the app still uploads and answers.
    }
  }
}

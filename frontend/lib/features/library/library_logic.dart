import 'dart:async';

import 'package:flutter/foundation.dart';

import '../on_device_rag/on_device_rag.dart';
import 'document_info.dart';
import 'library_api.dart';

final libraryLogic = LibraryLogic();

class LibraryLogic extends ChangeNotifier {
  LibraryLogic() {
    // Indexing, deletion and the document shipped with the app all change
    // the local catalog; follow it instead of waiting for a manual refresh.
    documentCatalog.addListener(_onCatalogChanged);
  }

  final LibraryApi _api = LibraryApi();

  void _onCatalogChanged() => unawaited(refresh());
  final List<DocumentInfo> documents = [];
  bool isLoading = false;
  bool isUploading = false;
  String? error;
  Timer? _poll;

  /// Re-reads the local catalog. Cheap: it is a small JSON list in
  /// localStorage, so polling during indexing costs nothing.
  Future<void> refresh({bool showSpinner = false}) async {
    if (showSpinner) {
      isLoading = true;
      notifyListeners();
    }
    documents
      ..clear()
      ..addAll(_api.list());
    error = null;
    isLoading = false;
    notifyListeners();
  }

  Future<void> upload({
    required String name,
    required Uint8List bytes,
  }) async {
    isUploading = true;
    error = null;
    notifyListeners();
    try {
      // Returns once the text is extracted and stored; embedding continues
      // in the background and the polling below picks the result up.
      await _api.upload(name, bytes);
      await refresh();
      _startPolling();
    } catch (failure) {
      error = _message(failure);
    }
    isUploading = false;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    try {
      await _api.delete(id);
      await refresh();
    } catch (failure) {
      error = _message(failure);
      notifyListeners();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await refresh();
      if (!documents.any((document) => document.isProcessing)) {
        timer.cancel();
      }
    });
  }

  String _message(Object failure) =>
      failure.toString().replaceFirst('Exception: ', '');
}

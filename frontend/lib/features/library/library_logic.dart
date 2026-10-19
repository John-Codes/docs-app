import 'dart:async';

import 'package:flutter/foundation.dart';

import 'document_info.dart';
import 'library_api.dart';

final libraryLogic = LibraryLogic();

class LibraryLogic extends ChangeNotifier {
  final LibraryApi _api = LibraryApi();
  final List<DocumentInfo> documents = [];
  bool isLoading = false;
  bool isUploading = false;
  String? error;
  Timer? _poll;

  Future<void> refresh({bool showSpinner = false}) async {
    if (showSpinner) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final items = await _api.list();
      documents
        ..clear()
        ..addAll(items);
      error = null;
    } catch (failure) {
      error = _message(failure);
    }
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
    _poll = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await refresh();
      if (!documents.any((document) => document.isProcessing)) {
        timer.cancel();
      }
    });
  }

  String _message(Object failure) =>
      failure.toString().replaceFirst('Exception: ', '');
}

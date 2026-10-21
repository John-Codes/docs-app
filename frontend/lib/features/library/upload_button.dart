import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'copyable_error.dart';
import 'library_logic.dart';

class UploadButton extends StatelessWidget {
  const UploadButton({super.key});

  Future<void> _pick(BuildContext context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await libraryLogic.upload(name: file.name, bytes: bytes);
    // An upload can fail before any document exists (extraction, storage),
    // and the failure is the one thing worth reading — so it comes to the
    // user with a copy button instead of sitting in the list behind them.
    final failure = libraryLogic.error;
    if (failure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: CopyableError(failure, maxLines: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: libraryLogic,
      builder: (context, _) {
        final busy = libraryLogic.isUploading;
        return FilledButton.icon(
          onPressed: busy ? null : () => _pick(context),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded, size: 20),
          label: Text(busy ? 'Uploading…' : 'Upload PDF'),
        );
      },
    );
  }
}

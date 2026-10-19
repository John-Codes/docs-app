import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'library_logic.dart';

class UploadButton extends StatelessWidget {
  const UploadButton({super.key});

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await libraryLogic.upload(name: file.name, bytes: bytes);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: libraryLogic,
      builder: (context, _) {
        final busy = libraryLogic.isUploading;
        return FilledButton.icon(
          onPressed: busy ? null : _pick,
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

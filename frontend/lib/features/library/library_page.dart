import 'package:flutter/material.dart';

import 'document_card.dart';
import 'error_banner.dart';
import 'library_empty_state.dart';
import 'library_header.dart';
import 'library_logic.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    libraryLogic.refresh(showSpinner: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: libraryLogic,
      builder: (context, _) {
        final documents = libraryLogic.documents;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              children: [
                const LibraryHeader(),
                if (libraryLogic.error != null) ...[
                  const SizedBox(height: 18),
                  ErrorBanner(message: libraryLogic.error!),
                ],
                const SizedBox(height: 26),
                if (libraryLogic.isLoading && documents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (documents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: LibraryEmptyState(),
                  )
                else
                  ...documents.map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DocumentCard(document: document),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'download_sections.dart';
import 'local_ai_state.dart';

/// Opens the one-time download explanation. Closing the sheet never
/// cancels a running download — it simply continues in the background.
Future<void> showLocalDownloadSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const LocalDownloadSheet(),
  );
}

/// Two models, two jobs: the search model indexes and retrieves, the
/// answer model writes on-device replies. Cloud answers only need search.
class LocalDownloadSheet extends StatelessWidget {
  const LocalDownloadSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localAiState,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'On-device AI',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(_explanation),
              const SizedBox(height: 20),
              const SearchModelSection(),
              if (!localAiState.modelReady) ...[
                const SizedBox(height: 20),
                const AnswerModelSection(),
              ],
            ],
          ),
        );
      },
    );
  }
}

const _explanation =
    'Everything stays in this browser: your PDFs, the passages, and the '
    'numbers used to search them. Downloads run in the background and chat '
    'keeps working meanwhile. Cloud answers stay available as a fallback.';

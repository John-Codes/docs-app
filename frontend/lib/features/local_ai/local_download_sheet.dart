import 'package:flutter/material.dart';

import 'local_ai_state.dart';
import 'local_model_store.dart';

/// Opens the one-time download explanation. Closing the sheet never
/// cancels a running download — it simply continues in the background.
Future<void> showLocalDownloadSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const LocalDownloadSheet(),
  );
}

class LocalDownloadSheet extends StatelessWidget {
  const LocalDownloadSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localAiState,
      builder: (context, _) {
        return Padding(
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
              _actions(context),
            ],
          ),
        );
      },
    );
  }

  Widget _actions(BuildContext context) {
    if (localAiState.modelReady) {
      return FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Ready — close'),
      );
    }
    if (localAiState.downloadActive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: localAiState.downloadProgress / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Downloading… you can close this and keep chatting — '
            'we\'ll switch the toggle on when it\'s done.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: localModelStore.download,
      icon: const Icon(Icons.download_rounded),
      label: const Text('Download (about 530 MB)'),
    );
  }
}

const _explanation =
    'Answers can run fully on your device — private and offline. '
    'It\'s a one-time download of about 530 MB stored by your browser, '
    'and your chat keeps working normally while it downloads. '
    'Cloud answers stay available as an always-on fallback.';

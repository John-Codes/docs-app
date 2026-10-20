import 'package:flutter/material.dart';

import '../on_device_rag/search_model_store.dart';
import 'download_progress.dart';
import 'local_ai_state.dart';
import 'local_model_store.dart';

/// The Gecko search model: required for every answer, cloud or on-device.
class SearchModelSection extends StatelessWidget {
  const SearchModelSection({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    if (localAiState.searchReady) {
      return Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search model ready — documents stay on this device',
              style: style,
            ),
          ),
        ],
      );
    }
    if (localAiState.searchDownloadActive) {
      return DownloadProgress(
        label: 'Search model ${localAiState.searchProgress}%',
        value: localAiState.searchProgress / 100,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Search model (about 114 MB)', style: style),
        const SizedBox(height: 6),
        const Text(
          'Indexes your PDFs and finds the passages that answer a question. '
          'Required for all answers, cloud or on-device.',
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: searchModelStore.download,
          icon: const Icon(Icons.search_rounded),
          label: Text(
            localAiState.searchFailed
                ? 'Retry search model download'
                : 'Download search model',
          ),
        ),
      ],
    );
  }
}

/// The optional on-device answer model.
class AnswerModelSection extends StatelessWidget {
  const AnswerModelSection({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    if (localAiState.downloadFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localAiState.downloadError ?? 'The download could not start.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: localModelStore.download,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry download'),
          ),
        ],
      );
    }
    if (localAiState.downloadActive) {
      return DownloadProgress(
        label: 'Answer model ${localAiState.downloadProgress}%',
        value: localAiState.downloadProgress / 100,
        onStop: localModelStore.cancel,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('On-device answers (about 530 MB)', style: style),
        const SizedBox(height: 6),
        const Text(
          'Optional: the model that writes answers on this device, with no '
          'internet. Cloud answers keep working without it.',
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: localModelStore.download,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download answer model'),
        ),
      ],
    );
  }
}

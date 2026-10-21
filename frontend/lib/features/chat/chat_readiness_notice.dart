import 'package:flutter/material.dart';

import '../local_ai/local_ai.dart';
import '../on_device_rag/on_device_rag.dart';
import 'readiness_stage.dart';

/// What the chat says while the device is still getting ready.
///
/// The chat is the first screen, so a new user types a question before the
/// search model is installed, while it downloads, or while the manual is
/// still being indexed. Each of those is a normal stage of setup, not a
/// fault, but with no word from the app the answer looks broken. This panel
/// names the stage and shows live progress, then disappears for good once
/// everything is ready.
///
/// It sits above the input rather than in the message list, so it cannot be
/// scrolled away and never looks like a stale reply.
class ChatReadinessNotice extends StatelessWidget {
  const ChatReadinessNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([localAiState, documentCatalog]),
      builder: (context, _) {
        final stage = readinessStage(
          searchReady: localAiState.searchReady,
          searchDownloading: localAiState.searchDownloadActive,
          indexing: documentCatalog.find(BundledDocument.id)?.isProcessing ??
              false,
        );
        if (stage == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _NoticeCard(stage: _Readiness.of(stage)),
        );
      },
    );
  }
}

/// One numbered setup stage, with an optional progress bar and action.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.stage});

  final _Readiness stage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Leading(stage: stage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stage.detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (stage.showProgress) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: stage.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            if (stage.actionLabel != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: stage.onAction,
                  icon: Icon(stage.actionIcon),
                  label: Text(stage.actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The icon, or a spinner while something is actively loading.
class _Leading extends StatelessWidget {
  const _Leading({required this.stage});

  final _Readiness stage;

  @override
  Widget build(BuildContext context) {
    if (stage.busy) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    return Icon(stage.icon, color: Theme.of(context).colorScheme.primary);
  }
}

/// One stage's copy and controls, built from live state at render time.
class _Readiness {
  const _Readiness({
    required this.title,
    required this.detail,
    required this.icon,
    this.busy = false,
    this.showProgress = false,
    this.progress,
    this.actionLabel,
    this.actionIcon = Icons.download_rounded,
    this.onAction,
  });

  final String title;
  final String detail;
  final IconData icon;
  final bool busy;
  final bool showProgress;

  /// Null makes the bar indeterminate — used while indexing, where the work
  /// has no percentage to report.
  final double? progress;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  factory _Readiness.of(ReadinessStage stage) => switch (stage) {
    ReadinessStage.downloadingSearch => _Readiness.downloadingSearch(),
    ReadinessStage.needsSearch => _Readiness.needsSearch(),
    ReadinessStage.indexingManual => _Readiness.indexingManual(),
  };

  factory _Readiness.downloadingSearch() => _Readiness(
    title: 'Getting this device ready',
    detail:
        'Downloading the search model — it reads your documents and finds '
        'the right pages. This happens once.',
    icon: Icons.downloading_rounded,
    busy: true,
    showProgress: true,
    progress: localAiState.searchProgress / 100,
  );

  factory _Readiness.needsSearch() {
    final failed = localAiState.searchFailed;
    return _Readiness(
      title: 'One step before you can ask',
      detail: failed
          ? 'The search model download did not finish. It reads your '
                'documents and finds the right pages — about 114 MB, once.'
          : 'This device needs a small search model before it can read your '
                'documents. About 114 MB, downloaded once.',
      icon: failed ? Icons.error_outline_rounded : Icons.search_rounded,
      actionLabel: failed ? 'Retry download' : 'Download now',
      actionIcon: failed ? Icons.refresh_rounded : Icons.download_rounded,
      onAction: searchModelStore.download,
    );
  }

  factory _Readiness.indexingManual() => const _Readiness(
    title: 'Preparing the HardRock manual',
    detail:
        'Reading the pages and making them searchable. You can ask about it '
        'in a moment.',
    icon: Icons.menu_book_rounded,
    busy: true,
    showProgress: true,
  );
}
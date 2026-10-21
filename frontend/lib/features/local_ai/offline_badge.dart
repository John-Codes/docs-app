import 'package:flutter/material.dart';

import 'local_ai_state.dart';
import 'local_download_sheet.dart';
import 'local_model_store.dart';

/// App-wide status badge for the on-device features. Invisible until the
/// engine is up; otherwise walks the user through readiness:
///
///   "Get search" → "Search 42%" → "Get offline mode" → "Offline ready ✓"
///
/// The search model is required even for cloud answers, so this badge is
/// the way to get it on devices that are not auto-downloading. Downloads
/// always run in the background — the badge is a status light, never a
/// blocker. It also announces once, with a snackbar, when a model lands.
class OfflineBadge extends StatefulWidget {
  const OfflineBadge({super.key});

  @override
  State<OfflineBadge> createState() => _OfflineBadgeState();
}

class _OfflineBadgeState extends State<OfflineBadge> {
  bool _wasDownloading = false;

  @override
  void initState() {
    super.initState();
    localAiState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    localAiState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (_wasDownloading &&
        !localAiState.downloadActive &&
        !localAiState.searchDownloadActive &&
        localAiState.modelReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline mode is ready — answers work without '
              'internet.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
    _wasDownloading =
        localAiState.downloadActive || localAiState.searchDownloadActive;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localAiState,
      builder: (context, _) {
        if (!localAiState.engineReady) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _badge(),
        );
      },
    );
  }

  Widget _badge() {
    if (localAiState.searchDownloadActive) {
      return _progressChip(
        localAiState.searchProgress,
        tooltip: 'Downloading the search model',
      );
    }
    if (!localAiState.searchReady) {
      return ActionChip(
        avatar: Icon(
          localAiState.searchFailed
              ? Icons.refresh_rounded
              : Icons.search_rounded,
          size: 18,
        ),
        label: Text(localAiState.searchFailed ? 'Retry search' : 'Get search'),
        onPressed: _showSheet,
      );
    }
    if (localAiState.downloadActive) {
      return _progressChip(
        localAiState.downloadProgress,
        tooltip: 'Downloading the answer model',
      );
    }
    if (localAiState.downloadFailed) {
      return ActionChip(
        avatar: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Retry download'),
        tooltip: localAiState.downloadError,
        onPressed: localModelStore.download,
      );
    }
    if (!localAiState.modelReady) {
      return ActionChip(
        avatar: const Icon(Icons.offline_bolt_outlined, size: 18),
        label: const Text('Get offline mode'),
        onPressed: _showSheet,
      );
    }
    return ActionChip(
      avatar: Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: const Text('Offline ready'),
      onPressed: _showSheet,
    );
  }

  Widget _progressChip(int progress, {required String tooltip}) {
    return ActionChip(
      avatar: SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          value: progress / 100,
        ),
      ),
      label: Text('$progress%'),
      tooltip: tooltip,
      onPressed: _showSheet,
    );
  }

  Future<void> _showSheet() async {
    await showLocalDownloadSheet(context);
  }
}

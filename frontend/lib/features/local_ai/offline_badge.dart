import 'package:flutter/material.dart';

import 'local_ai_state.dart';
import 'local_download_sheet.dart';
import 'local_model_store.dart';

/// App-wide status badge for the offline mode. Invisible on devices that
/// cannot run it; otherwise walks the user through readiness:
///
///   "Get offline mode" → "Downloading 42%" → "Offline ready ✓"
///
/// The download always runs in the background — the badge is a status
/// light, never a blocker. It also announces once, with a snackbar, when
/// the model finishes downloading.
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
        localAiState.modelReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline mode is ready — answers work without '
              'internet.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
    _wasDownloading = localAiState.downloadActive;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localAiState,
      builder: (context, _) {
        if (!localAiState.deviceSupported || !localAiState.engineReady) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _badge(),
        );
      },
    );
  }

  Widget _badge() {
    if (localAiState.downloadActive) {
      return ActionChip(
        avatar: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            value: localAiState.downloadProgress / 100,
          ),
        ),
        label: Text('${localAiState.downloadProgress}%'),
        onPressed: _showSheet,
      );
    }
    if (localAiState.downloadFailed) {
      return ActionChip(
        avatar: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Retry download'),
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

  Future<void> _showSheet() async {
    await showLocalDownloadSheet(context);
  }
}

import 'package:flutter/material.dart';

import 'local_ai_state.dart';
import 'local_download_sheet.dart';
import 'local_model_store.dart';

/// A compact row above the chat input. It is INVISIBLE unless the device
/// passed the capability gate and the engine is up, so unsupported devices
/// and every failure case simply see the normal cloud chat.
class LocalModeBar extends StatelessWidget {
  const LocalModeBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localAiState,
      builder: (context, _) {
        if (!localAiState.deviceSupported || !localAiState.engineReady) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: _content(context),
        );
      },
    );
  }

  Widget _content(BuildContext context) {
    if (localAiState.downloadActive) return _progressRow();
    if (localAiState.downloadFailed) return _retryRow();
    if (!localAiState.modelReady) return _offerRow(context);
    return _modeSwitch();
  }

  /// Non-blocking progress strip: the chat below it stays fully usable.
  Widget _progressRow() {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LinearProgressIndicator(
            value: localAiState.downloadProgress / 100,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Text('${localAiState.downloadProgress}%'),
      ],
    );
  }

  Widget _retryRow() {
    return ActionChip(
      avatar: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Model download failed — retry'),
      onPressed: localModelStore.download,
    );
  }

  Widget _offerRow(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.memory_rounded, size: 18),
      label: const Text('Try on-device AI'),
      onPressed: () => showLocalDownloadSheet(context),
    );
  }

  Widget _modeSwitch() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Cloud')),
        ButtonSegment(value: true, label: Text('On device')),
      ],
      selected: {localAiState.useLocal},
      onSelectionChanged: (selection) =>
          localAiState.update(local: selection.first),
      showSelectedIcon: false,
    );
  }
}

import 'package:flutter/material.dart';

import 'local_ai_state.dart';

/// Cloud ⇄ on-device answer switch, shown above the chat input once the
/// offline model is downloaded. Everything before that point lives in the
/// app-wide offline badge, so the chat stays clean until local answers are
/// actually possible.
class LocalModeBar extends StatelessWidget {
  const LocalModeBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localAiState,
      builder: (context, _) {
        if (!localAiState.available) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Cloud')),
              ButtonSegment(value: true, label: Text('On device')),
            ],
            selected: {localAiState.useLocal},
            onSelectionChanged: (selection) =>
                localAiState.update(local: selection.first),
            showSelectedIcon: false,
          ),
        );
      },
    );
  }
}

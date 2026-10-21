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
          // ~1rem beneath the switch so it does not crowd the notice or the
          // message box on phones.
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Cloud')),
              ButtonSegment(value: true, label: Text('On device')),
            ],
            selected: {localAiState.useLocal},
            onSelectionChanged: (selection) =>
                _switchMode(context, selection.first),
            showSelectedIcon: false,
          ),
        );
      },
    );
  }

  void _switchMode(BuildContext context, bool useLocal) {
    localAiState.update(local: useLocal);
    if (!useLocal || localAiState.speedNoticeShown) return;
    localAiState.update(speedNotice: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Answers now run on your device — speed depends on its hardware, '
          'so some replies may take longer.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }
}

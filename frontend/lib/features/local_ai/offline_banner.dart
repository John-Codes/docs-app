import 'package:flutter/material.dart';

import 'browser_connectivity.dart';
import 'local_ai_state.dart';

/// Wraps the app body so a slim status strip appears directly under the
/// app bar whenever the browser reports it is offline. Green when the
/// on-device model can still answer, amber when answers resume later.
class OfflineAwareBody extends StatelessWidget {
  const OfflineAwareBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([browserConnectivity, localAiState]),
      builder: (context, _) {
        if (browserConnectivity.online) return child;
        return Column(
          children: [
            OfflineBanner(ready: localAiState.available),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.ready});

  /// Whether on-device answers work right now (green) or not (amber).
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: ready ? colors.secondaryContainer : colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              ready
                  ? Icons.offline_bolt_rounded
                  : Icons.cloud_off_rounded,
              size: 18,
              color: ready
                  ? colors.onSecondaryContainer
                  : colors.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ready
                    ? "You're offline — on-device answers still work"
                    : "You're offline — answers resume when you reconnect",
                style: TextStyle(
                  color: ready
                      ? colors.onSecondaryContainer
                      : colors.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

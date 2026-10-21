import 'package:flutter_test/flutter_test.dart';

import 'package:docs_app/features/chat/readiness_stage.dart';

void main() {
  group('readinessStage', () {
    test('a downloading search model shows progress, not a download button', () {
      // Getting this wrong tells a user to download what is already
      // downloading, which reads as "nothing is happening".
      expect(
        readinessStage(
          searchReady: false,
          searchDownloading: true,
          indexing: false,
        ),
        ReadinessStage.downloadingSearch,
      );
    });

    test('a missing search model asks for the download', () {
      expect(
        readinessStage(
          searchReady: false,
          searchDownloading: false,
          indexing: false,
        ),
        ReadinessStage.needsSearch,
      );
    });

    test('the manual indexing is its own stage', () {
      expect(
        readinessStage(
          searchReady: true,
          searchDownloading: false,
          indexing: true,
        ),
        ReadinessStage.indexingManual,
      );
    });

    test('nothing is shown once the app can answer', () {
      // The panel must vanish for good, or it becomes permanent clutter.
      expect(
        readinessStage(
          searchReady: true,
          searchDownloading: false,
          indexing: false,
        ),
        isNull,
      );
    });

    test('a ready model outranks a stale downloading flag', () {
      // The flags come from separate async paths and can briefly disagree;
      // ready is the one that matters, so the panel must not linger.
      expect(
        readinessStage(
          searchReady: true,
          searchDownloading: true,
          indexing: false,
        ),
        isNull,
      );
    });

    test('indexing is never shown before the model is ready', () {
      // Indexing cannot start without the embedder, so this state would be a
      // lie; the model stage has to win.
      expect(
        readinessStage(
          searchReady: false,
          searchDownloading: false,
          indexing: true,
        ),
        ReadinessStage.needsSearch,
      );
    });
  });
}

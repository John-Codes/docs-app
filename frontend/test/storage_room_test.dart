import 'package:flutter_test/flutter_test.dart';

import 'package:docs_app/features/local_ai/storage_room.dart';

void main() {
  group('StorageRoom', () {
    test('enough when the free part covers the need', () {
      const room = StorageRoom(
        quotaBytes: 2 * 1024 * 1024 * 1024,
        usedBytes: 512 * 1024 * 1024,
        neededBytes: 828 * 1024 * 1024,
      );
      expect(room.freeBytes, 1536 * 1024 * 1024);
      expect(room.enough, isTrue);
      expect(room.shortfallBytes, 0);
    });

    test('not enough when the quota is mostly used up', () {
      // The exact edge case: a large quota that is already spent still
      // cannot hold a 700 MB model, and checking quota alone misses it.
      const room = StorageRoom(
        quotaBytes: 1200 * 1024 * 1024,
        usedBytes: 1100 * 1024 * 1024,
        neededBytes: 828 * 1024 * 1024,
      );
      expect(room.freeBytes, 100 * 1024 * 1024);
      expect(room.enough, isFalse);
      expect(room.shortfallBytes, 728 * 1024 * 1024);
    });

    test('a usage above the quota never reports negative free space', () {
      const room = StorageRoom(
        quotaBytes: 100,
        usedBytes: 300,
        neededBytes: 50,
      );
      expect(room.freeBytes, 0);
      expect(room.enough, isFalse);
      expect(room.shortfallBytes, 50);
    });
  });

  group('neededFor', () {
    test('adds the search model when it is not installed yet', () {
      final answerOnly = neededFor(
        modelBytes: answerModelBytes,
        searchInstalled: true,
      );
      final both = neededFor(
        modelBytes: answerModelBytes,
        searchInstalled: false,
      );
      expect(both - answerOnly, searchModelBytes);
      expect(answerOnly, answerModelBytes + storageHeadroomBytes);
    });
  });

  group('isStorageFailure', () {
    test('recognises the browser refusing to store the file', () {
      expect(isStorageFailure('QuotaExceededError: Quota exceeded.'), isTrue);
      expect(isStorageFailure('Exception: no space left on device'), isTrue);
      expect(isStorageFailure('Out of memory'), isTrue);
    });

    test('does not mistake a network failure for a storage one', () {
      expect(isStorageFailure('Network error: Failed to fetch'), isFalse);
      expect(isStorageFailure('HTTP 403 Forbidden'), isFalse);
    });
  });

  group('storageShortageMessage', () {
    test('states how much is needed and how much is free', () {
      const room = StorageRoom(
        quotaBytes: 400 * 1024 * 1024,
        usedBytes: 290 * 1024 * 1024,
        neededBytes: 828 * 1024 * 1024,
      );
      final message = storageShortageMessage(room);
      expect(message, contains('828 MB'));
      expect(message, contains('110 MB'));
      expect(message, contains('Retry'));
    });
  });
}

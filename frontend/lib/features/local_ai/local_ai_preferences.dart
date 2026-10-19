import 'package:shared_preferences/shared_preferences.dart';

const _declinedKey = 'local_ai_download_declined';

final localAiPreferences = LocalAiPreferences();

/// Remembers whether the user said "not now" to the offline model download.
///
/// Smart auto-download never overrides a human decision: once declined,
/// the 530 MB download only ever starts again from the explicit
/// "Get offline mode" button.
class LocalAiPreferences {
  Future<void> markDownloadDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_declinedKey, true);
  }

  Future<void> clearDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_declinedKey, false);
  }

  Future<bool> isDownloadDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_declinedKey) ?? false;
  }
}

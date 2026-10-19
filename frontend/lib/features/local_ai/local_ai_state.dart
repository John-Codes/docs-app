import 'package:flutter/foundation.dart';

/// Single source of truth for the optional on-device AI mode.
///
/// Every flag starts false, so the app behaves exactly like the cloud-only
/// build until the local engine proves itself ready. Any failure anywhere
/// just leaves flags false, which silently keeps the cloud chat in charge.
final localAiState = LocalAiState();

class LocalAiState extends ChangeNotifier {
  /// The browser can realistically run a WebGPU-class model (checked once
  /// at startup; false on old iPhones, weak Androids, non-WebGPU browsers).
  bool deviceSupported = false;

  /// The flutter_edge_ai engine initialized without errors.
  bool engineReady = false;

  /// The model file is downloaded and active on this device.
  bool modelReady = false;

  /// A model download is running in the background right now.
  bool downloadActive = false;

  /// The last download attempt failed. Cloud chat is never affected.
  bool downloadFailed = false;

  /// Plain-language reason for the last download failure, shown only in
  /// the download sheet / badge tooltip. Null when nothing to show.
  String? downloadError;

  /// 0-100 while a download runs.
  int downloadProgress = 0;

  /// The user picked on-device answers for the next messages.
  bool useLocal = false;

  /// True only when local answers can actually be served right now.
  bool get available => deviceSupported && engineReady && modelReady;

  void update({
    bool? supported,
    bool? engine,
    bool? model,
    bool? downloading,
    bool? failed,
    int? progress,
    bool? local,
    String? error,
  }) {
    if (supported != null) deviceSupported = supported;
    if (engine != null) engineReady = engine;
    if (model != null) modelReady = model;
    if (downloading != null) downloadActive = downloading;
    if (failed != null) downloadFailed = failed;
    if (progress != null) downloadProgress = progress;
    if (local != null) useLocal = local;
    if (error != null) downloadError = error.isEmpty ? null : error;
    notifyListeners();
  }
}

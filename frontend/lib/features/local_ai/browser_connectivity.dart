import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// What the browser reports about connectivity: the online/offline events
/// that drive the offline banner, plus the only metered-connection signal
/// the web offers (Chromium's navigator.connection).
final browserConnectivity = BrowserConnectivity();

class BrowserConnectivity extends ChangeNotifier {
  BrowserConnectivity() : online = _isOnline() {
    if (kIsWeb) {
      web.window.addEventListener('online', _wentOnline.toJS);
      web.window.addEventListener('offline', _wentOffline.toJS);
    }
  }

  /// Latest browser-reported connection state.
  bool online;

  /// True only when the connection is verifiably unmetered: Wi-Fi or
  /// Ethernet with the browser's data saver off. Safari and Firefox do not
  /// expose this, so "unknown" counts as metered — the app then shows the
  /// "Get offline mode" button instead of spending 700 MB of mobile data.
  bool isUnmetered() {
    if (!kIsWeb) return false;
    try {
      final navigator = web.window.navigator as JSObject;
      final connection = navigator['connection'];
      if (connection == null || connection.isUndefinedOrNull) return false;
      final type = (connection as JSObject)['type'];
      if (type == null || type.isUndefinedOrNull) return false;
      final typeName = (type as JSString).toDart;
      if (typeName != 'wifi' && typeName != 'ethernet') return false;
      final saveData = (connection)['saveData'];
      final savingData = saveData == null || saveData.isUndefinedOrNull
          ? false
          : (saveData as JSBoolean).toDart;
      return !savingData;
    } catch (_) {
      return false;
    }
  }

  void _wentOnline(web.Event _) => _set(true);

  void _wentOffline(web.Event _) => _set(false);

  void _set(bool value) {
    if (online == value) return;
    online = value;
    notifyListeners();
  }
}

bool _isOnline() => kIsWeb && web.window.navigator.onLine;

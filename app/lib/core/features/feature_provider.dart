import 'package:flutter/foundation.dart';

import 'feature_service.dart';

/// Mirrors the React FeatureContext: caches the Super Admin's effective
/// feature map for the current business and platform, and fails open
/// (treats an unknown/unfetched key as enabled) so a slow or failed network
/// call can't lock a legitimate user out of the whole app — the backend is
/// still the real gate on every write via require_feature().
class FeatureProvider extends ChangeNotifier {
  final _service = FeatureService();

  Map<String, bool> _features = {};
  bool _loaded = false;
  int? _lastBusinessId;

  bool get loaded => _loaded;

  bool isEnabled(String key) => _features[key] != false;

  /// Called from the ChangeNotifierProxyProvider update() whenever
  /// AuthProvider's currentBusiness changes, so switching businesses always
  /// refetches the right map instead of showing the previous business's.
  void syncBusiness(int? businessId) {
    if (businessId == _lastBusinessId) return;
    _lastBusinessId = businessId;
    if (businessId != null) load();
  }

  Future<void> load() async {
    try {
      final map = await _service.effective();
      _features = map;
    } catch (_) {
      // keep whatever was last cached
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }
}

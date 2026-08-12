import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide online/offline signal, backed by [Connectivity]'s interface-level
/// reachability (has *a* network path, not necessarily working internet).
/// Callers that make an actual request still fall back to catching Dio's
/// connectionError as the real ground truth — this is the fast, ambient
/// signal used to decide "read from cache" vs. "hit the network" and to
/// drive the offline indicator / auto-sync trigger.
class ConnectivityService {
  ConnectivityService._() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      _setOnline(!results.contains(ConnectivityResult.none) && results.isNotEmpty);
    });
    Connectivity().checkConnectivity().then((r) => _setOnline(!r.contains(ConnectivityResult.none) && r.isNotEmpty));
  }

  static final ConnectivityService instance = ConnectivityService._();

  late final StreamSubscription<List<ConnectivityResult>> _sub;

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  void _setOnline(bool value) {
    if (isOnline.value != value) isOnline.value = value;
  }

  Future<bool> checkOnline() async {
    final results = await Connectivity().checkConnectivity();
    final online = !results.contains(ConnectivityResult.none) && results.isNotEmpty;
    _setOnline(online);
    return online;
  }

  void dispose() => _sub.cancel();
}

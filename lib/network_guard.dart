import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus { online, noConnection, noData }

/// Singleton that monitors network connectivity and actual internet data access.
/// Call [startMonitoring] once at app startup. Notifies listeners on status change.
class NetworkGuard extends ChangeNotifier {
  static final NetworkGuard _instance = NetworkGuard._internal();
  factory NetworkGuard() => _instance;
  NetworkGuard._internal();

  NetworkStatus _status = NetworkStatus.online;
  NetworkStatus get status => _status;

  bool _checking = false;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _pingTimer;

  void startMonitoring() {
    _sub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _check());

    // Periodic check every 5s to catch cases where connectivity event is missed
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _check());

    _check(); // immediate initial check
  }

  void stopMonitoring() {
    _sub?.cancel();
    _pingTimer?.cancel();
  }

  /// Manually re-check — called by the retry button on overlay.
  Future<void> retryCheck() => _check();

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final results = await Connectivity().checkConnectivity();

      final hasInterface = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);

      if (!hasInterface) {
        _updateStatus(NetworkStatus.noConnection);
        return;
      }

      // Has a network interface — now check actual internet reachability
      final hasData = await _pingInternet();
      _updateStatus(hasData ? NetworkStatus.online : NetworkStatus.noData);
    } finally {
      _checking = false;
    }
  }

  Future<bool> _pingInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 6));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      // Try a fallback
      try {
        final socket = await Socket.connect('8.8.8.8', 53,
            timeout: const Duration(seconds: 5));
        socket.destroy();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  void _updateStatus(NetworkStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }
}

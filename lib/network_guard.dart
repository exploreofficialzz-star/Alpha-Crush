import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus { online, noConnection, noData }

/// Monitors network connectivity and actual internet data.
///
/// Why HTTP and not DNS/sockets:
///   DNS lookups and TCP port-53 sockets can "succeed" even with no real
///   internet — a router or captive portal will intercept and respond.
///   HTTP requests through dart:io's HttpClient use the same underlying
///   stack as AdMob, so if ads can load, these probes will also succeed.
///
/// Detection flow:
///   1. connectivity_plus → no interface at all → noConnection immediately.
///   2. HTTP HEAD to 4 endpoints in parallel (including Android's own
///      generate_204 check). ANY 2xx/3xx/4xx = online. ALL fail = noData.
///   3. reportOnline() — AdsManager calls this whenever an ad loads, which
///      is definitive proof of connectivity and clears any noData state.
class NetworkGuard extends ChangeNotifier {
  static final NetworkGuard _instance = NetworkGuard._internal();
  factory NetworkGuard() => _instance;
  NetworkGuard._internal();

  NetworkStatus _status    = NetworkStatus.online;
  NetworkStatus get status => _status;

  bool _checking = false;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _pingTimer;

  static const Duration _probeTimeout  = Duration(seconds: 6);
  static const Duration _overallTimeout = Duration(seconds: 9);

  // Android's own connectivity check + 3 reliable fallbacks
  static const List<String> _endpoints = [
    'http://connectivitycheck.gstatic.com/generate_204',
    'http://clients3.google.com/generate_204',
    'https://www.google.com',
    'https://www.cloudflare.com',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  void startMonitoring() {
    _sub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _check());
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    _check();
  }

  void stopMonitoring() {
    _sub?.cancel();
    _pingTimer?.cancel();
  }

  Future<void> retryCheck() async {
    await _check();
  }

  /// Call this from AdsManager whenever any ad loads successfully.
  /// Ad loading is definitive proof of internet — clears noData immediately.
  void reportOnline() => _updateStatus(NetworkStatus.online);

  // ── Core check ─────────────────────────────────────────────────────────────
  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final results = await Connectivity().checkConnectivity();
      final hasInterface = results.any((r) =>
          r == ConnectivityResult.wifi   ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);

      if (!hasInterface) {
        _updateStatus(NetworkStatus.noConnection);
        return;
      }

      final hasData = await _probeParallel();
      _updateStatus(hasData ? NetworkStatus.online : NetworkStatus.noData);
    } finally {
      _checking = false;
    }
  }

  // ── Parallel HTTP probes ───────────────────────────────────────────────────
  Future<bool> _probeParallel() async {
    final completer = Completer<bool>();
    int settled = 0;
    final total  = _endpoints.length;

    for (final url in _endpoints) {
      _probeHttp(url).then((ok) {
        settled++;
        if (ok && !completer.isCompleted) {
          completer.complete(true); // first success → online
        } else if (!ok && settled == total && !completer.isCompleted) {
          completer.complete(false); // all failed → no data
        }
      });
    }

    return completer.future.timeout(_overallTimeout, onTimeout: () => false);
  }

  Future<bool> _probeHttp(String url) async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = _probeTimeout
        ..badCertificateCallback = (_, __, ___) => true; // don't block on cert

      final uri     = Uri.parse(url);
      final request = await client
          .headUrl(uri)
          .timeout(_probeTimeout);

      request.headers.set('Cache-Control', 'no-cache');
      request.headers.set('User-Agent',    'Mozilla/5.0 AlphaCrush/1.0');

      final response = await request.close().timeout(_probeTimeout);
      await response.drain<void>(); // consume body so socket is released
      // Any HTTP response at all = we reached the server = internet works
      return true;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  // ── State update ───────────────────────────────────────────────────────────
  void _updateStatus(NetworkStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }
}

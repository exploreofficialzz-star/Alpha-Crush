import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus { online, noConnection, noData }

/// Singleton that monitors network connectivity and actual internet data.
///
/// Detection strategy:
///   1. connectivity_plus — checks whether a network interface is active
///      (WiFi, mobile, ethernet). No interface = [NetworkStatus.noConnection].
///   2. Multi-endpoint parallel ping — fires 6 checks simultaneously
///      (3 DNS lookups + 3 TCP socket probes on port 53).
///      If ANY single check succeeds within the timeout = [NetworkStatus.online].
///      If ALL fail = [NetworkStatus.noData] (interface present but no data).
class NetworkGuard extends ChangeNotifier {
  static final NetworkGuard _instance = NetworkGuard._internal();
  factory NetworkGuard() => _instance;
  NetworkGuard._internal();

  NetworkStatus _status = NetworkStatus.online;
  NetworkStatus get status => _status;

  bool _checking = false;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _pingTimer;

  // ── Endpoints checked in parallel ─────────────────────────────────────────
  static const List<String> _dnsHosts = [
    'google.com',
    'cloudflare.com',
    'amazon.com',
  ];

  /// (host, port) — all well-known DNS servers, port 53 is nearly always open
  static const List<(String, int)> _tcpEndpoints = [
    ('8.8.8.8',         53),  // Google Public DNS
    ('1.1.1.1',         53),  // Cloudflare DNS
    ('9.9.9.9',         53),  // Quad9 DNS
  ];

  static const Duration _probeTimeout   = Duration(seconds: 5);
  static const Duration _overallTimeout = Duration(seconds: 7);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  void startMonitoring() {
    _sub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _check());

    // Periodic heartbeat every 5 s
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _check());

    _check(); // immediate check on startup
  }

  void stopMonitoring() {
    _sub?.cancel();
    _pingTimer?.cancel();
  }

  Future<void> retryCheck() => _check();

  // ── Core check ─────────────────────────────────────────────────────────────
  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      // Step 1 — does any network interface exist?
      final results = await Connectivity().checkConnectivity();
      final hasInterface = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);

      if (!hasInterface) {
        _updateStatus(NetworkStatus.noConnection);
        return;
      }

      // Step 2 — interface present; verify actual internet data
      final hasData = await _hasInternetData();
      _updateStatus(hasData ? NetworkStatus.online : NetworkStatus.noData);
    } finally {
      _checking = false;
    }
  }

  /// Fires all probes simultaneously. Returns true as soon as ANY one succeeds.
  /// Returns false only if every probe fails or the overall timeout elapses.
  Future<bool> _hasInternetData() async {
    final probes = <Future<bool>>[
      ..._dnsHosts.map(_probeDns),
      ..._tcpEndpoints.map((ep) => _probeTcp(ep.$1, ep.$2)),
    ];

    // Race: resolve with true the moment any probe succeeds
    final completer = Completer<bool>();

    int failed = 0;
    for (final probe in probes) {
      probe.then((ok) {
        if (ok && !completer.isCompleted) completer.complete(true);
      }).catchError((_) {
        failed++;
        if (failed == probes.length && !completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    // Safety net — if neither branch fires within the overall timeout → no data
    return completer.future
        .timeout(_overallTimeout, onTimeout: () => false);
  }

  Future<bool> _probeDns(String host) async {
    try {
      final result =
          await InternetAddress.lookup(host).timeout(_probeTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeTcp(String host, int port) async {
    try {
      final socket =
          await Socket.connect(host, port, timeout: _probeTimeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
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

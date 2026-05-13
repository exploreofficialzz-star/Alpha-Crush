import 'package:flutter/material.dart';
import 'network_guard.dart';
import 'ads_manager.dart';

/// Wraps the entire app. When network is gone or ads are blocked,
/// renders a full-screen blocking overlay that prevents interaction
/// with the game until the issue is resolved.
class OverlayGate extends StatefulWidget {
  final Widget child;
  const OverlayGate({super.key, required this.child});

  @override
  State<OverlayGate> createState() => _OverlayGateState();
}

class _OverlayGateState extends State<OverlayGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    NetworkGuard().addListener(_onStateChange);
    AdsManager().addListener(_onStateChange);
  }

  @override
  void dispose() {
    NetworkGuard().removeListener(_onStateChange);
    AdsManager().removeListener(_onStateChange);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  _OverlayType? get _activeOverlay {
    final net = NetworkGuard().status;
    if (net == NetworkStatus.noConnection) return _OverlayType.noConnection;
    if (net == NetworkStatus.noData) return _OverlayType.noData;
    if (AdsManager().adsBlocked) return _OverlayType.adsBlocked;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _activeOverlay;
    return Stack(
      children: [
        widget.child,
        if (overlay != null)
          _BlockingOverlay(
            type: overlay,
            pulse: _pulse,
            onRetry: () async {
              if (overlay == _OverlayType.noConnection ||
                  overlay == _OverlayType.noData) {
                await NetworkGuard().retryCheck();
              } else {
                AdsManager().retryAdLoad();
              }
            },
          ),
      ],
    );
  }
}

enum _OverlayType { noConnection, noData, adsBlocked }

class _BlockingOverlay extends StatelessWidget {
  final _OverlayType type;
  final Animation<double> pulse;
  final VoidCallback onRetry;

  const _BlockingOverlay({
    required this.type,
    required this.pulse,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        color: const Color(0xF00D0D1A), // near-opaque dark
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Animated icon ──────────────────────────────────────────────
              ScaleTransition(
                scale: pulse,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _iconColor.withOpacity(0.15),
                    border: Border.all(color: _iconColor, width: 2),
                  ),
                  child: Icon(_icon, color: _iconColor, size: 48),
                ),
              ),
              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Subtitle ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ── Retry button ──────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              // ── Hint for ads ───────────────────────────────────────────────
              if (type == _OverlayType.adsBlocked) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Alpha Crush is free thanks to ads.\n'
                    'Disable your ad blocker or VPN, then tap Retry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color get _iconColor {
    switch (type) {
      case _OverlayType.noConnection:
        return const Color(0xFFFF4B4B);
      case _OverlayType.noData:
        return const Color(0xFFFFB347);
      case _OverlayType.adsBlocked:
        return const Color(0xFF6A11CB);
    }
  }

  IconData get _icon {
    switch (type) {
      case _OverlayType.noConnection:
        return Icons.wifi_off_rounded;
      case _OverlayType.noData:
        return Icons.signal_wifi_statusbar_connected_no_internet_4_rounded;
      case _OverlayType.adsBlocked:
        return Icons.block_rounded;
    }
  }

  String get _title {
    switch (type) {
      case _OverlayType.noConnection:
        return 'No Internet Connection';
      case _OverlayType.noData:
        return 'Internet Connected\nBut No Data';
      case _OverlayType.adsBlocked:
        return 'Ads Are Blocked';
    }
  }

  String get _subtitle {
    switch (type) {
      case _OverlayType.noConnection:
        return 'Check your Wi-Fi or mobile data settings to continue playing.';
      case _OverlayType.noData:
        return 'You\'re connected to a network but can\'t reach the internet. '
            'Check your Wi-Fi or data plan.';
      case _OverlayType.adsBlocked:
        return 'Enable ads to continue the game. '
            'Ads keep Alpha Crush free for everyone.';
    }
  }

  String get _buttonLabel {
    switch (type) {
      case _OverlayType.noConnection:
        return 'Retry Connection';
      case _OverlayType.noData:
        return 'Retry';
      case _OverlayType.adsBlocked:
        return 'Retry';
    }
  }
}

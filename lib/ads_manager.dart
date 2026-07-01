import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'network_guard.dart';

/// Production AdMob IDs for Alpha Crush (Android).
/// iOS IDs are placeholders — update before enabling iOS builds.
class _AdIds {
  // ── Android production ────────────────────────────────────────────────────
  static const String androidBanner        = 'ca-app-pub-2492078126313994/2810925382';
  static const String androidInterstitial  = 'ca-app-pub-2492078126313994/9811448001';
  static const String androidRewarded      = 'ca-app-pub-2492078126313994/8498366339';

  // ── iOS (placeholder — update before shipping iOS) ─────────────────────
  static const String iosBanner            = 'ca-app-pub-3940256099942544/2934735716';
  static const String iosInterstitial      = 'ca-app-pub-3940256099942544/4411468910';
  static const String iosRewarded          = 'ca-app-pub-3940256099942544/1712485313';
}

class AdsManager extends ChangeNotifier {
  static final AdsManager _instance = AdsManager._internal();
  factory AdsManager() => _instance;
  AdsManager._internal();

  // ─── Ad unit selectors ────────────────────────────────────────────────────
  static String get _bannerAdUnitId =>
      Platform.isAndroid ? _AdIds.androidBanner : _AdIds.iosBanner;

  static String get _interstitialAdUnitId =>
      Platform.isAndroid ? _AdIds.androidInterstitial : _AdIds.iosInterstitial;

  static String get _rewardedAdUnitId =>
      Platform.isAndroid ? _AdIds.androidRewarded : _AdIds.iosRewarded;

  // ─── State ────────────────────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  bool _interstitialReady    = false;
  bool _rewardedReady        = false;
  bool _isShowingInterstitial = false;

  // ── Ad-block detection ───────────────────────────────────────────────────
  int  _bannerFailCount       = 0;
  int  _interstitialFailCount = 0;
  bool _adsBlocked            = false;
  static const int _blockThreshold = 3;

  bool get adsBlocked => _adsBlocked;

  // ── Remove Ads (IAP) ────────────────────────────────────────────────────
  // The persisted flag itself is owned by IapManager (one source of truth);
  // this is just the in-memory gate that showInterstitial() and
  // BannerAdWidget check on every call, so a purchase takes effect
  // instantly everywhere without needing a screen rebuild/navigation.
  bool _adsRemoved = false;
  bool get adsRemoved => _adsRemoved;

  void setAdsRemoved(bool removed) {
    if (_adsRemoved == removed) return;
    _adsRemoved = removed;
    notifyListeners();
  }

  void _recordAdFailure(String type) {
    if (type == 'banner')       _bannerFailCount++;
    if (type == 'interstitial') _interstitialFailCount++;
    if (_bannerFailCount >= _blockThreshold &&
        _interstitialFailCount >= _blockThreshold &&
        !_adsBlocked) {
      _adsBlocked = true;
      notifyListeners();
    }
  }

  void _recordAdSuccess(String type) {
    if (type == 'banner')       _bannerFailCount = 0;
    if (type == 'interstitial') _interstitialFailCount = 0;
    if (_adsBlocked) {
      _adsBlocked = false;
      notifyListeners();
    }
  }

  /// Called by the retry button on the ad-blocked overlay.
  void retryAdLoad() {
    _bannerFailCount = 0;
    _interstitialFailCount = 0;
    _adsBlocked = false;
    notifyListeners();
    _loadInterstitial();
    _loadRewarded();
  }

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  // ─── Banner ───────────────────────────────────────────────────────────────
  BannerAd createBanner({
    required AdSize size,
    required void Function(Ad, LoadAdError) onError,
  }) {
    final banner = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) { _recordAdSuccess('banner'); NetworkGuard().reportOnline(); },
        onAdFailedToLoad: (ad, error) {
          _recordAdFailure('banner');
          onError(ad, error);
        },
      ),
    );
    banner.load();
    return banner;
  }

  // ─── Interstitial ─────────────────────────────────────────────────────────
  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd    = ad;
          _interstitialReady = true;
          _recordAdSuccess('interstitial');
          NetworkGuard().reportOnline();
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) {
          _interstitialReady = false;
          _recordAdFailure('interstitial');
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  // ── Frequency capping ─────────────────────────────────────────────────
  // Google's own interstitial best-practice guidance is to gate on elapsed
  // time since the last impression rather than a fixed per-action counter
  // ("only show an interstitial after at least two minutes"). This is a
  // single app-wide floor — every call site benefits automatically, so a
  // future screen that calls showInterstitial() can't accidentally stack
  // ads even if it forgets to think about frequency itself.
  DateTime? _lastInterstitialShownAt;
  static const Duration minInterstitialGap = Duration(seconds: 120);

  bool get _cooldownElapsed {
    final last = _lastInterstitialShownAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= minInterstitialGap;
  }

  void showInterstitial({
    VoidCallback? onDismissed,
    bool ignoreCooldown = false,
  }) {
    if (_adsRemoved) {
      onDismissed?.call();
      return;
    }
    if (_isShowingInterstitial) return;
    if (!ignoreCooldown && !_cooldownElapsed) {
      // Too soon since the last interstitial — skip silently and let the
      // caller's flow continue as if no ad were configured here at all.
      onDismissed?.call();
      return;
    }
    if (!_interstitialReady || _interstitialAd == null) {
      onDismissed?.call();
      _loadInterstitial();
      return;
    }
    _lastInterstitialShownAt = DateTime.now();
    _isShowingInterstitial = true;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd        = null;
        _interstitialReady     = false;
        _isShowingInterstitial = false;
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd        = null;
        _interstitialReady     = false;
        _isShowingInterstitial = false;
        _loadInterstitial();
        onDismissed?.call();
      },
    );
    _interstitialAd!.show();
    _interstitialReady = false;
  }

  // ─── Rewarded ─────────────────────────────────────────────────────────────
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd    = ad;
          _rewardedReady = true;
        },
        onAdFailedToLoad: (_) {
          _rewardedReady = false;
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  bool get isRewardedReady => _rewardedReady;

  void showRewarded({
    required void Function(RewardItem reward) onEarned,
    VoidCallback? onFailed,
  }) {
    if (!_rewardedReady || _rewardedAd == null) {
      onFailed?.call();
      _loadRewarded();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd    = null;
        _rewardedReady = false;
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd    = null;
        _rewardedReady = false;
        onFailed?.call();
        _loadRewarded();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (_, reward) => onEarned(reward));
    _rewardedReady = false;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }
}

// ─── Banner widget ────────────────────────────────────────────────────────────
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdsManager().adsRemoved) return; // no ad requested at all
    _banner = BannerAd(
      adUnitId: AdsManager._bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          AdsManager()._recordAdSuccess('banner');
          NetworkGuard().reportOnline();
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (_, __) {
          AdsManager()._recordAdFailure('banner');
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _banner!.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdsManager(),
      builder: (_, __) {
        if (AdsManager().adsRemoved) return const SizedBox.shrink();
        if (!_loaded || _banner == null) return const SizedBox(height: 50);
        return SizedBox(
          height: _banner!.size.height.toDouble(),
          width:  _banner!.size.width.toDouble(),
          child: AdWidget(ad: _banner!),
        );
      },
    );
  }
}

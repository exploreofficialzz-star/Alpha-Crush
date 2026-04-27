import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsManager {
  static final AdsManager _instance = AdsManager._internal();
  factory AdsManager() => _instance;
  AdsManager._internal();

  // Ad Unit IDs - Using test IDs for development, replace with production IDs
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'
        : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'
        : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'
        : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  }

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;

  BannerAd? get bannerAd => _bannerAd;
  bool get isBannerAdLoaded => _bannerAd != null;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadBannerAd();
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: ${error.message}');
          ad.dispose();
          _bannerAd = null;
        },
      ),
    );
    _bannerAd!.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdReady = false;
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialAdReady = false;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: ${error.message}');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isRewardedAdReady = false;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isRewardedAdReady = false;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: ${error.message}');
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  void showBannerAd() {
    if (_bannerAd == null) {
      _loadBannerAd();
    }
  }

  void showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      _loadInterstitialAd();
    }
  }

  void showRewardedAd({required Function() onRewarded, Function()? onFailed}) {
    if (_isRewardedAdReady && _rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          onRewarded();
        },
      );
    } else {
      onFailed?.call();
      _loadRewardedAd();
    }
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

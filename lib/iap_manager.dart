import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ads_manager.dart';
import 'currency_manager.dart';

/// Product IDs — these are the strings you create in Play Console →
/// Monetize → Products, and in App Store Connect → Monetization →
/// In-App Purchases. They MUST match exactly (case-sensitive) or the
/// store simply won't return product data for them — nothing crashes,
/// the purchase section just quietly shows no products.
///
/// 'remove_ads' is a non-consumable managed product (bought once, owned
/// forever, must support restore). The coin packs are consumables (can
/// be bought repeatedly, do NOT need restore — a consumed coin pack is
/// gone from the store's perspective, which is correct: the coins already
/// landed in the player's balance).
class IapProductIds {
  static const String removeAds = 'remove_ads';
  static const String coinPackSmall = 'coin_pack_small';
  static const String coinPackLarge = 'coin_pack_large';

  static const Set<String> consumables = {coinPackSmall, coinPackLarge};
  static const Set<String> all = {removeAds, coinPackSmall, coinPackLarge};
}

class IapManager extends ChangeNotifier {
  static final IapManager _instance = IapManager._internal();
  factory IapManager() => _instance;
  IapManager._internal();

  static const String _adsRemovedKey = 'ads_removed';

  /// Coins granted per consumable pack. Centralized here so the settings
  /// UI and the fulfilment logic below always agree on the payout.
  /// Large pack gives ~10% more coins-per-dollar than buying 5.5x the
  /// small pack would imply — the standard "bigger bundle, better rate"
  /// shape that makes the bigger purchase feel like the smart choice.
  static const Map<String, int> coinPackAmounts = {
    IapProductIds.coinPackSmall: 100,
    IapProductIds.coinPackLarge: 550,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  List<ProductDetails> _products = [];
  bool _storeAvailable = false;
  bool _adsRemoved = false;
  bool _isLoading = true;
  String? _lastError;

  bool get storeAvailable => _storeAvailable;
  bool get adsRemoved => _adsRemoved;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  List<ProductDetails> get products => _products;

  ProductDetails? _byId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  ProductDetails? get removeAdsProduct => _byId(IapProductIds.removeAds);
  ProductDetails? get coinPackSmallProduct =>
      _byId(IapProductIds.coinPackSmall);
  ProductDetails? get coinPackLargeProduct =>
      _byId(IapProductIds.coinPackLarge);

  /// True once we've heard back from the store, whether or not any
  /// products actually loaded — lets the UI distinguish "still checking"
  /// from "checked, nothing available" (e.g. products not yet created in
  /// console, or running on an emulator with no store).
  bool get isReady => !_isLoading;

  Future<void> initialize() async {
    // Sync the persisted Remove-Ads flag into AdsManager FIRST, before
    // any screen has a chance to build a banner — this doesn't depend on
    // store connectivity at all, so it works even fully offline.
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_adsRemovedKey) ?? false;
    if (_adsRemoved) AdsManager().setAdsRemoved(true);
    notifyListeners();

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _sub?.cancel(),
      onError: (_) {},
    );

    final response = await _iap.queryProductDetails(IapProductIds.all);
    _products = response.productDetails;
    if (response.notFoundIDs.isNotEmpty) {
      // Expected until the matching products are created in both
      // consoles — not an error state to surface to end users.
      debugPrint(
          'IAP: not yet found in store — create these in Play Console / '
          'App Store Connect: ${response.notFoundIDs.join(', ')}');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        _lastError = purchase.error?.message;
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _fulfil(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        // Required by both stores — an unacknowledged purchase gets
        // auto-refunded (Play) or keeps re-appearing (App Store).
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _fulfil(PurchaseDetails purchase) async {
    if (purchase.productID == IapProductIds.removeAds) {
      _adsRemoved = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adsRemovedKey, true);
      AdsManager().setAdsRemoved(true);
      notifyListeners();
    } else if (coinPackAmounts.containsKey(purchase.productID)) {
      final amount = coinPackAmounts[purchase.productID]!;
      await CurrencyManager().earn(amount, reason: 'iap_${purchase.productID}');
    }
  }

  Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    if (IapProductIds.consumables.contains(product.id)) {
      await _iap.buyConsumable(purchaseParam: param);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  /// Required by Apple's App Store Review Guidelines (3.1.1) for any app
  /// with non-consumable purchases — must offer a way to restore them on
  /// a new device without repurchasing. Harmless to expose on Android too.
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

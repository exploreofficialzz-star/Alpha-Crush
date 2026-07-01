import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'sound_manager.dart';
import 'ads_manager.dart';
import 'iap_manager.dart';
import 'currency_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D0D1A),
              Color(0xFF1A0533),
              Color(0xFF0D0D1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70),
                      onPressed: () {
                        SoundManager().playTap();
                        Navigator.pop(context);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'SETTINGS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Sound Effects toggle ──
              _buildSettingTile(
                'Sound Effects',
                SoundManager().soundEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                SoundManager().soundEnabled,
                (value) {
                  setState(() {
                    SoundManager().toggleSound();
                    SoundManager().playTap(); // plays if sound was just turned ON
                  });
                },
              ),

              const SizedBox(height: 16),

              // ── Music toggle ──
              _buildSettingTile(
                'Background Music',
                SoundManager().musicEnabled
                    ? Icons.music_note_rounded
                    : Icons.music_off_rounded,
                SoundManager().musicEnabled,
                (value) {
                  setState(() {
                    SoundManager().toggleMusic();
                  });
                },
              ),

              const SizedBox(height: 32),

              // ── Ad info tile ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFD700).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.play_circle_rounded,
                            color: Color(0xFFFFD700), size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rewarded Ads',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            SizedBox(height: 3),
                            Text(
                                'Watch ads for hints, +30s time, or to continue after game over',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Remove Ads + Coin Packs (IAP) ──
              AnimatedBuilder(
                animation: Listenable.merge([IapManager(), CurrencyManager()]),
                builder: (_, __) => _buildIapSection(),
              ),

              const Spacer(),

              // ── App info ──
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('ALPHA CRUSH',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white38,
                          letterSpacing: 3)),
                  const SizedBox(height: 4),
                  const Text('v1.1.0',
                      style: TextStyle(fontSize: 12, color: Colors.white24)),
                  const SizedBox(height: 4),
                  const Text('By chAs Tech Group',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white24,
                          letterSpacing: 2)),
                  const SizedBox(height: 32),
                ],
              ),

              // ── Banner ad ──
              const BannerAdWidget(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
      String title, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.white.withOpacity(0.10), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (value
                        ? const Color(0xFF6A11CB)
                        : Colors.white24)
                    .withOpacity(0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: value
                      ? const Color(0xFF9C6AFF)
                      : Colors.white38,
                  size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF9C6AFF),
              activeTrackColor:
                  const Color(0xFF6A11CB).withOpacity(0.40),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white.withOpacity(0.10),
            ),
          ],
        ),
      ),
    );
  }

  // ── IAP: Remove Ads + Coin Packs ────────────────────────────────────────
  Widget _buildIapSection() {
    // Still checking with the store — show nothing rather than a flash of
    // an empty/broken-looking section while the query is in flight.
    if (!IapManager().isReady) return const SizedBox(height: 8);

    final removeAds = IapManager().removeAdsProduct;
    final small = IapManager().coinPackSmallProduct;
    final large = IapManager().coinPackLargeProduct;

    // Store reachable but no matching products found. Expected until
    // 'remove_ads' / 'coin_pack_small' / 'coin_pack_large' are created in
    // Play Console and App Store Connect — nothing broken to show a real
    // user here, so the section just doesn't render.
    if (removeAds == null && small == null && large == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFFFD700), size: 16),
              const SizedBox(width: 6),
              Text('${CurrencyManager().balance} Crush Coins',
                  style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (removeAds != null) _buildRemoveAdsTile(removeAds),
          if (small != null || large != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (small != null)
                  Expanded(child: _buildCoinPackCard(small)),
                if (small != null && large != null)
                  const SizedBox(width: 10),
                if (large != null)
                  Expanded(child: _buildCoinPackCard(large)),
              ],
            ),
          ],
          if (removeAds != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                SoundManager().playTap();
                IapManager().restorePurchases();
              },
              child: const Text('Restore Purchases',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemoveAdsTile(ProductDetails product) {
    final owned = IapManager().adsRemoved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: owned
              ? [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.07)]
              : [const Color(0xFF6A11CB).withOpacity(0.35),
                 const Color(0xFF2575FC).withOpacity(0.25)],
        ),
        border: Border.all(
            color: owned
                ? Colors.white.withOpacity(0.10)
                : const Color(0xFF9C6AFF).withOpacity(0.5),
            width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.block_rounded,
                color: Color(0xFFFFD700), size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remove Ads',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('No banners, no interstitials — forever',
                    style: TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
          if (owned)
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF66BB6A), size: 26)
          else
            GestureDetector(
              onTap: () {
                SoundManager().playTap();
                IapManager().buy(product);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                ),
                child: Text(product.price,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoinPackCard(ProductDetails product) {
    final amount = IapManager.coinPackAmounts[product.id] ?? 0;
    final isLarge = product.id == IapProductIds.coinPackLarge;
    return GestureDetector(
      onTap: () {
        SoundManager().playTap();
        IapManager().buy(product);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.07),
          border: Border.all(
              color: isLarge
                  ? const Color(0xFFFFD700).withOpacity(0.4)
                  : Colors.white.withOpacity(0.10),
              width: 1),
        ),
        child: Column(
          children: [
            if (isLarge)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFFFD700).withOpacity(0.18),
                ),
                child: const Text('BEST VALUE',
                    style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
            Icon(Icons.monetization_on_rounded,
                color: const Color(0xFFFFD700).withOpacity(0.9), size: 26),
            const SizedBox(height: 6),
            Text('$amount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            const Text('COINS',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.10),
              ),
              child: Text(product.price,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

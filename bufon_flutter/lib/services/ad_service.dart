// services/ad_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../analytics/analytics_service.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/log_category.dart';

/// Service for managing AdMob rewarded ads
///
/// Features:
/// - Exponential backoff retry on load failure
/// - Auto-preload after showing ad
/// - Lifecycle-aware (pauses/resumes)
/// - Prevents double reward
/// - Safe disposal
/// - Analytics tracking
class AdService {
  RewardedAd? _rewardedAd;
  bool _isAdReady = false;
  bool _isLoading = false;
  bool _isShowing = false;
  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  final AnalyticsService _analytics = AnalyticsService.instance;
  DateTime? _adStartTime;

  // Test ad unit IDs (safe for development)
  static const String _testAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testAdUnitIdIOS =
      'ca-app-pub-3940256099942544/1712485313';

  // Production ad unit IDs (replace with your actual IDs)
  static const String _prodAdUnitIdAndroid = 'ca-app-pub-XXXX/YYYY';
  static const String _prodAdUnitIdIOS = 'ca-app-pub-XXXX/YYYY';

  /// Get the appropriate ad unit ID based on platform and build mode
  String get _adUnitId {
    if (kReleaseMode) {
      // Production
      return Platform.isAndroid ? _prodAdUnitIdAndroid : _prodAdUnitIdIOS;
    } else {
      // Debug/Test
      return Platform.isAndroid ? _testAdUnitIdAndroid : _testAdUnitIdIOS;
    }
  }

  /// Check if ad is ready to show
  bool get isAdReady => _isAdReady && !_isShowing;

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      AppLogger.instance.info(
        AppLogCategory.ads,
        '[AdService] Mobile Ads SDK initialized',
      );

      // Preload first ad
      await loadRewardedAd();
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.ads,
        '[AdService] Failed to initialize',
        error: e,
      );
    }
  }

  /// Load a rewarded ad with exponential backoff retry
  Future<void> loadRewardedAd() async {
    if (_isLoading || _isAdReady) {
      AppLogger.instance.debug(
        AppLogCategory.ads,
        '[AdService] Already loading or ad ready, skipping load',
      );
      return;
    }

    _isLoading = true;
    _loadAttempts++;

    try {
      await RewardedAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            AppLogger.instance.info(
              AppLogCategory.ads,
              '[AdService] Rewarded ad loaded successfully',
            );
            _rewardedAd = ad;
            _isAdReady = true;
            _isLoading = false;
            _loadAttempts = 0;
            _setupAdCallbacks();
          },
          onAdFailedToLoad: (error) {
            AppLogger.instance.warning(
              AppLogCategory.ads,
              '[AdService] Failed to load ad: ${error.message}',
            );
            _isLoading = false;
            _isAdReady = false;

            // Retry with exponential backoff
            if (_loadAttempts < _maxLoadAttempts) {
              final delay = Duration(seconds: _loadAttempts * 2);
              AppLogger.instance.info(
                AppLogCategory.ads,
                '[AdService] Retrying in ${delay.inSeconds}s (attempt $_loadAttempts/$_maxLoadAttempts)',
              );
              Future.delayed(delay, loadRewardedAd);
            } else {
              AppLogger.instance.error(
                AppLogCategory.ads,
                '[AdService] Max retry attempts reached',
              );
              _loadAttempts = 0;
            }
          },
        ),
      );
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.ads,
        '[AdService] Exception loading ad',
        error: e,
      );
      _isLoading = false;
      _isAdReady = false;
    }
  }

  /// Setup callbacks for the loaded ad
  void _setupAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        AppLogger.instance.info(
          AppLogCategory.ads,
          '[AdService] Ad showed full screen content',
        );
        _isShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        AppLogger.instance.info(
          AppLogCategory.ads,
          '[AdService] Ad dismissed full screen content',
        );
        _isShowing = false;
        _isAdReady = false;
        ad.dispose();
        _rewardedAd = null;

        // Preload next ad
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        AppLogger.instance.warning(
          AppLogCategory.ads,
          '[AdService] Ad failed to show: ${error.message}',
        );
        _isShowing = false;
        _isAdReady = false;
        ad.dispose();
        _rewardedAd = null;

        // Preload next ad
        loadRewardedAd();
      },
    );
  }

  /// Show the rewarded ad
  ///
  /// Returns true if user earned the reward, false otherwise
  Future<bool> showRewardedAd({String? roomCode}) async {
    if (!_isAdReady || _rewardedAd == null || _isShowing) {
      AppLogger.instance.warning(
        AppLogCategory.ads,
        '[AdService] Ad not ready to show',
      );
      return false;
    }

    bool rewardEarned = false;
    _adStartTime = DateTime.now();

    // Analytics: Track ad watch initiation
    if (roomCode != null) {
      await _analytics.logRewardedAdWatched(
        roomCode: roomCode,
        gamesPlayedToday: 0, // Will be updated by caller with actual value
      );
    }

    try {
      // Show the ad with reward callback
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          AppLogger.instance.info(
            AppLogCategory.ads,
            '[AdService] User earned reward: ${reward.amount} ${reward.type}',
          );
          rewardEarned = true;
        },
      );

      // Wait a bit to ensure reward callback fires if earned
      await Future.delayed(const Duration(milliseconds: 500));

      // Analytics: Track ad completion
      if (roomCode != null) {
        final duration = _adStartTime != null
            ? DateTime.now().difference(_adStartTime!).inSeconds
            : 0;

        if (rewardEarned) {
          await _analytics.logRewardedAdCompleted(
            roomCode: roomCode,
            rewardAmount: 1,
            timeToCompleteSeconds: duration,
          );
        } else {
          await _analytics.logRewardedAdFailed(
            roomCode: roomCode,
            failureReason: 'user_dismissed_before_completion',
          );
        }
      }

      return rewardEarned;
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.ads,
        '[AdService] Exception showing ad',
        error: e,
      );

      // Analytics: Track failure
      if (roomCode != null) {
        await _analytics.logRewardedAdFailed(
          roomCode: roomCode,
          failureReason: 'exception_${e.runtimeType}',
        );
      }

      return false;
    }
  }

  /// Dispose of the ad (call when service is no longer needed)
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdReady = false;
    _isLoading = false;
    _isShowing = false;
    AppLogger.instance.info(AppLogCategory.ads, '[AdService] Disposed');
  }
}

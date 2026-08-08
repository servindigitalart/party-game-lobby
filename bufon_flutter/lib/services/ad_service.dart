// services/ad_service.dart
import '../core/telemetry/telemetry_event.dart';
import '../core/config/admob_config.dart';
import '../core/logging/log_level.dart';
import '../core/telemetry/game_telemetry_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
  final GameTelemetryService _telemetry = GameTelemetryService.instance;
  DateTime? _adStartTime;

  /// Rewarded unit for this platform and build mode.
  ///
  /// Every AdMob identifier lives in [AdMobConfig]; none are declared here.
  /// This used to hold four constants of its own, two of which were
  /// unfilled placeholders that release builds actually
  /// requested.
  String get _adUnitId => AdMobConfig.instance.rewardedId;

  /// Check if ad is ready to show
  bool get isAdReady => _isAdReady && !_isShowing;

  /// Whether the resolved ad units are safe to serve in this build.
  ///
  /// False only when a non-debug build resolved to a Google test unit.
  /// Checked before every load so a bad Remote Config override cannot start
  /// serving sample ads mid-session.
  bool get _idsAreSafe => AdMobConfig.instance.isSafeFor();

  void _reportUnsafeIds(String stage) {
    final offenders = AdMobConfig.instance.unsafeIds();
    // Fails the build in debug and profile; in release the load is refused
    // instead, because crashing a player's session over an ad is worse than
    // showing no ad.
    assert(
      offenders.isEmpty,
      'Release build resolved Google test ad ids: ${offenders.join(', ')}',
    );
    _telemetry.fail(
      AppLogCategory.ads,
      'ad_config_invalid',
      error: StateError(
        'Non-debug build resolved Google test ad ids: ${offenders.join(', ')}',
      ),
      payload: {'stage': stage},
    );
  }

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
    } catch (e, stackTrace) {
      _telemetry.fail(
        AppLogCategory.ads,
        'ad_service_init_failed',
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (!_idsAreSafe) _reportUnsafeIds('initialize');
  }

  /// Load a rewarded ad with exponential backoff retry
  Future<void> loadRewardedAd() async {
    // Refuse rather than serve Google's sample inventory against a real
    // account. isAdReady stays false, so the paywall shows its "no ad
    // available" path instead of a broken one.
    if (!_idsAreSafe) {
      _reportUnsafeIds('load');
      _isLoading = false;
      _isAdReady = false;
      return;
    }

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
            _isLoading = false;
            _isAdReady = false;

            final willRetry = _loadAttempts < _maxLoadAttempts;

            // No fill is the normal state of an ad network, and this path
            // retries on a backoff, so each attempt is a warning breadcrumb
            // rather than a crash report.
            _telemetry.fail(
              AppLogCategory.ads,
              'ad_load_failed',
              error: error,
              severity: AppLogLevel.warning,
              status: willRetry
                  ? TelemetryStatus.retried
                  : TelemetryStatus.failed,
              payload: {
                'ad_error_code': error.code,
                'attempt': _loadAttempts,
                'max_attempts': _maxLoadAttempts,
                'will_retry': willRetry,
              },
            );

            if (willRetry) {
              Future.delayed(
                Duration(seconds: _loadAttempts * 2),
                loadRewardedAd,
              );
              return;
            }

            // Only the exhausted case is escalated: it means the player
            // cannot unlock a game no matter how long they wait, which is
            // the failure that actually costs a session.
            _telemetry.fail(
              AppLogCategory.ads,
              'ad_load_retries_exhausted',
              error: error,
              payload: {'attempts': _maxLoadAttempts},
            );
            _loadAttempts = 0;
          },
        ),
      );
    } catch (e, stackTrace) {
      // An exception here is not "no fill": the request itself broke.
      _telemetry.fail(
        AppLogCategory.ads,
        'ad_load_failed',
        error: e,
        stackTrace: stackTrace,
        payload: {'attempt': _loadAttempts},
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

    // Room code already travels in Session Context, so the event no longer
    // needs one and fires even when the caller did not pass it.
    _telemetry.track(
      AppLogCategory.ads,
      'rewarded_ad_started',
      payload: {'ad_network': 'admob'},
    );

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

      final duration = _adStartTime != null
          ? DateTime.now().difference(_adStartTime!)
          : Duration.zero;

      if (rewardEarned) {
        _telemetry.track(
          AppLogCategory.ads,
          'rewarded_ad_completed',
          duration: duration,
          payload: {'ad_network': 'admob', 'reward_amount': 1},
        );
      } else {
        // Dismissing an ad early is ordinary user behaviour, not a defect:
        // warning severity keeps it out of crash reporting.
        _telemetry.track(
          AppLogCategory.ads,
          'rewarded_ad_completed',
          status: TelemetryStatus.failed,
          severity: AppLogLevel.warning,
          duration: duration,
          payload: {
            'ad_network': 'admob',
            'failure_reason': 'user_dismissed_before_completion',
          },
        );
      }

      return rewardEarned;
    } catch (e, stackTrace) {
      // The AppLogger.error that used to sit here produced a second crash
      // report for the same exception, because error-level logs are
      // reported too.
      _telemetry.fail(
        AppLogCategory.ads,
        'rewarded_ad_completed',
        error: e,
        stackTrace: stackTrace,
        payload: {
          'ad_network': 'admob',
          'failure_reason': 'exception_${e.runtimeType}',
        },
      );

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

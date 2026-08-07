// core/logging/log_category.dart

/// Functional area a log entry belongs to.
///
/// Every call into [AppLogger] must declare exactly one category, per
/// docs/engineering/LOGGING.md ("Every log belongs to one category").
enum AppLogCategory {
  app,
  navigation,
  room,
  player,
  gameplay,
  voting,
  firestore,
  firebase,
  analytics,
  crashlytics,
  network,
  performance,
  system,
  telemetry,
  purchases,
  monetization,
  ads,
}

extension AppLogCategoryLabel on AppLogCategory {
  /// Human-readable label used when formatting log output.
  String get label {
    switch (this) {
      case AppLogCategory.app:
        return 'App';
      case AppLogCategory.navigation:
        return 'Navigation';
      case AppLogCategory.room:
        return 'Room';
      case AppLogCategory.player:
        return 'Player';
      case AppLogCategory.gameplay:
        return 'Gameplay';
      case AppLogCategory.voting:
        return 'Voting';
      case AppLogCategory.firestore:
        return 'Firestore';
      case AppLogCategory.firebase:
        return 'Firebase';
      case AppLogCategory.analytics:
        return 'Analytics';
      case AppLogCategory.crashlytics:
        return 'Crashlytics';
      case AppLogCategory.network:
        return 'Network';
      case AppLogCategory.performance:
        return 'Performance';
      case AppLogCategory.system:
        return 'System';
      case AppLogCategory.telemetry:
        return 'Telemetry';
      case AppLogCategory.purchases:
        return 'Purchases';
      case AppLogCategory.monetization:
        return 'Monetization';
      case AppLogCategory.ads:
        return 'Ads';
    }
  }
}

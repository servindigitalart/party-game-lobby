// providers/ad_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ad_service.dart';

/// Provider for AdService
///
/// Creates a single instance of AdService that persists
/// across the app lifecycle
final adServiceProvider = Provider<AdService>((ref) {
  final adService = AdService();

  // Initialize on first access
  adService.initialize();

  // Cleanup on dispose
  ref.onDispose(() {
    adService.dispose();
  });

  return adService;
});

/// Provider for checking if ad is ready
final isAdReadyProvider = Provider<bool>((ref) {
  final adService = ref.watch(adServiceProvider);
  return adService.isAdReady;
});

// providers/monetization_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';
import '../domain/controllers/monetization_controller.dart';

/// Provider for LocalStorageService
///
/// This is a FutureProvider because LocalStorageService requires
/// async initialization of SharedPreferences
final localStorageServiceProvider = FutureProvider<LocalStorageService>((
  ref,
) async {
  return await LocalStorageService.create();
});

/// Provider for MonetizationController
///
/// Depends on LocalStorageService being initialized
final monetizationControllerProvider = Provider<MonetizationController>((ref) {
  // Get the LocalStorageService from the async provider
  final storageAsync = ref.watch(localStorageServiceProvider);

  // Return controller when storage is ready
  return storageAsync.when(
    data: (storage) => MonetizationController(storage),
    loading: () => throw StateError('LocalStorageService not yet initialized'),
    error: (error, stack) =>
        throw StateError('Failed to initialize LocalStorageService: $error'),
  );
});

/// Provider for remaining free games count
///
/// Returns null if Night Pass is active (unlimited games)
final remainingFreeGamesProvider = Provider<int?>((ref) {
  try {
    final controller = ref.watch(monetizationControllerProvider);
    return controller.getRemainingFreeGames();
  } catch (e) {
    // Storage not ready yet
    return null;
  }
});

/// Provider for Night Pass status
final hasActiveNightPassProvider = Provider<bool>((ref) {
  try {
    final controller = ref.watch(monetizationControllerProvider);
    return controller.hasActiveNightPass();
  } catch (e) {
    // Storage not ready yet
    return false;
  }
});

/// Provider for bonus games count
final bonusGamesCountProvider = Provider<int>((ref) {
  try {
    final controller = ref.watch(monetizationControllerProvider);
    return controller.getBonusGamesCount();
  } catch (e) {
    // Storage not ready yet
    return 0;
  }
});

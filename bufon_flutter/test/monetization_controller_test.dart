// test/monetization_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bufon_flutter/services/local_storage_service.dart';
import 'package:bufon_flutter/domain/controllers/monetization_controller.dart';
import 'package:bufon_flutter/core/exceptions.dart';

/// Unit tests for MonetizationController
///
/// Tests all business logic for the monetization system:
/// - Daily limit enforcement (3 free games)
/// - Day reset logic
/// - Bonus games consumption
/// - Night Pass activation and unlimited games
void main() {
  group('MonetizationController', () {
    late MonetizationController controller;
    late LocalStorageService storage;

    setUp(() async {
      // Initialize with empty storage before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      controller = MonetizationController(storage);
    });

    test('allows first 3 games per day', () async {
      // Should allow game 1
      expect(await controller.canPlayGame(), true);
      await controller.registerGamePlayed();

      // Should allow game 2
      expect(await controller.canPlayGame(), true);
      await controller.registerGamePlayed();

      // Should allow game 3
      expect(await controller.canPlayGame(), true);
      await controller.registerGamePlayed();

      // Should block game 4
      try {
        await controller.canPlayGame();
        fail('Should have thrown MonetizationException');
      } catch (e) {
        expect(e, isA<MonetizationException>());
      }
    });

    test('getRemainingFreeGames returns correct count', () async {
      // Start with 3 games
      expect(controller.getRemainingFreeGames(), 3);

      // Play one game
      await controller.registerGamePlayed();
      expect(controller.getRemainingFreeGames(), 2);

      // Play another
      await controller.registerGamePlayed();
      expect(controller.getRemainingFreeGames(), 1);

      // Play third
      await controller.registerGamePlayed();
      expect(controller.getRemainingFreeGames(), 0);
    });

    test('bonus games are consumed before blocking', () async {
      // Use all daily games
      for (int i = 0; i < 3; i++) {
        await controller.canPlayGame();
        await controller.registerGamePlayed();
      }

      // Should be blocked
      try {
        await controller.canPlayGame();
        fail('Should have thrown MonetizationException');
      } catch (e) {
        expect(e, isA<MonetizationException>());
      }

      // Grant 2 bonus games
      await controller.grantBonusGame(count: 2);
      expect(controller.getBonusGamesCount(), 2);

      // Should allow game with bonus
      expect(await controller.canPlayGame(), true);
      await controller.registerGamePlayed();
      expect(controller.getBonusGamesCount(), 1);

      // Should allow second bonus game
      expect(await controller.canPlayGame(), true);
      await controller.registerGamePlayed();
      expect(controller.getBonusGamesCount(), 0);

      // Should block again
      try {
        await controller.canPlayGame();
        fail('Should have thrown MonetizationException');
      } catch (e) {
        expect(e, isA<MonetizationException>());
      }
    });

    test('Night Pass grants unlimited games', () async {
      // Activate Night Pass for 1 hour
      await controller.activateNightPass(const Duration(hours: 1));

      expect(controller.hasActiveNightPass(), true);
      expect(controller.getRemainingFreeGames(), null); // null = unlimited

      // Should allow unlimited games
      for (int i = 0; i < 10; i++) {
        expect(await controller.canPlayGame(), true);
        await controller.registerGamePlayed();
      }

      // Should still have unlimited
      expect(controller.getRemainingFreeGames(), null);
      expect(controller.getGamesPlayedToday(), 0); // Not counting
      expect(controller.getBonusGamesCount(), 0); // Not consuming
    });

    test('bonus games show in remaining count', () async {
      // Use all daily games
      for (int i = 0; i < 3; i++) {
        await controller.registerGamePlayed();
      }

      expect(controller.getRemainingFreeGames(), 0);

      // Grant bonus games
      await controller.grantBonusGame(count: 5);
      expect(controller.getRemainingFreeGames(), 5);
    });

    test('Night Pass expiration', () async {
      // Activate Night Pass for 0 seconds (expired immediately)
      await controller.activateNightPass(const Duration(seconds: 0));

      // Should be expired
      expect(controller.hasActiveNightPass(), false);
    });

    test('day reset logic', () async {
      // This test would require mocking DateTime.now()
      // For now, just verify the storage reset works
      for (int i = 0; i < 3; i++) {
        await controller.registerGamePlayed();
      }

      expect(controller.getGamesPlayedToday(), 3);

      // Manually reset (simulates day change)
      await storage.resetDailyCounter();

      expect(controller.getGamesPlayedToday(), 0);
      expect(controller.getRemainingFreeGames(), 3);
    });
  });
}

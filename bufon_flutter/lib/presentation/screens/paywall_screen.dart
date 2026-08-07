// presentation/screens/paywall_screen.dart
import 'package:flutter/material.dart';
import '../../core/logging/log_category.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ad_service.dart';
import '../../services/iap_service.dart';
import '../../data/repositories/room_repository.dart';
import '../../providers/game_providers.dart';

/// Paywall screen shown when room hits monetization limit
///
/// Options:
/// 1. Watch rewarded ad (unlocks 1 more game)
/// 2. Buy Night Pass (12 hours unlimited games for $10 MXN)
class PaywallScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const PaywallScreen({super.key, required this.roomCode});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = false;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  @override
  void initState() {
    super.initState();
    _trackPaywallShown();
  }

  Future<void> _trackPaywallShown() async {
    // This read stays: gamesPlayedToday and adUnlocksRemaining are the
    // paywall's own trigger conditions, not shared Session Context.
    final repository = RoomRepository();
    final room = await repository.getRoom(widget.roomCode);
    if (room == null) return;

    _telemetry.track(
      AppLogCategory.purchases,
      'paywall_shown',
      payload: {
        'games_played_today': room.gamesPlayedToday,
        'trigger_reason': room.adUnlocksRemaining > 0
            ? 'no_bonus_games'
            : 'free_limit',
      },
    );
  }

  Future<void> _watchAd() async {
    setState(() => _isLoading = true);

    try {
      final adService = AdService();
      final repository = RoomRepository();

      // Check if ad is ready
      if (!adService.isAdReady) {
        await adService.loadRewardedAd();

        // Wait a moment for ad to load
        await Future.delayed(const Duration(seconds: 2));

        if (!adService.isAdReady && mounted) {
          _showError('El anuncio no está listo. Intenta de nuevo.');
          setState(() => _isLoading = false);
          return;
        }
      }

      // Show the ad (with analytics tracking inside AdService)
      final rewardEarned = await adService.showRewardedAd(
        roomCode: widget.roomCode,
      );

      if (!mounted) return;

      if (rewardEarned) {
        // Grant unlock to room atomically
        await repository.grantAdUnlock(widget.roomCode);

        // Success! Close paywall
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to retry game start
        }
      } else {
        _showError('No se completó el anuncio. Intenta de nuevo.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al mostrar el anuncio: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _buyNightPass() async {
    setState(() => _isLoading = true);

    try {
      final iapService = IAPService();
      await iapService.initialize();

      // Get user ID
      final userId = ref.read(userIdProvider);
      if (userId == null) {
        _showError('Error: Usuario no identificado');
        setState(() => _isLoading = false);
        return;
      }

      // Initiate purchase
      final success = await iapService.buyNightPass(widget.roomCode, userId);

      if (!mounted) return;

      if (success) {
        // Success! Night Pass activated
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Night Pass activado! 12 horas ilimitadas'),
            backgroundColor: Colors.green,
          ),
        );

        // Close paywall
        Navigator.of(context).pop(true);
      } else {
        _showError('La compra no se completó. Intenta de nuevo.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al procesar la compra: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text(
          'Desbloquear Sala',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE94560)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F3460),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Color(0xFFE94560),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      '¡Ya jugaron 3 partidas hoy!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      'La sala necesita desbloquearse para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Option 1: Watch Ad
                    _buildOptionCard(
                      icon: Icons.play_circle_outline,
                      title: 'Ver Anuncio',
                      subtitle: 'Desbloquea 1 partida más',
                      color: const Color(0xFF0F3460),
                      onTap: _watchAd,
                    ),

                    const SizedBox(height: 16),

                    // Option 2: Night Pass
                    _buildOptionCard(
                      icon: Icons.star_outline,
                      title: 'Night Pass',
                      subtitle: '12 horas ilimitadas • \$10 MXN',
                      color: const Color(0xFFE94560),
                      onTap: _buyNightPass,
                      premium: true,
                    ),

                    const SizedBox(height: 32),

                    // Info text
                    Text(
                      'Cualquier jugador puede desbloquear la sala para todos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool premium = false,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: premium
              ? Border.all(color: const Color(0xFFFFD700), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (premium) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star,
                          size: 20,
                          color: Color(0xFFFFD700),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

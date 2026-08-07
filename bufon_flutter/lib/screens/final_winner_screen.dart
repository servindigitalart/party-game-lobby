import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/avatar.dart';
import '../presentation/widgets/confetti_widget.dart';
import '../presentation/widgets/animated_primary_button.dart';
import '../presentation/widgets/share_victory_card.dart';
import '../presentation/navigation/page_transitions.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/logging/log_category.dart';
import '../core/logging/log_level.dart';
import 'home_screen.dart';

class FinalWinnerScreen extends StatefulWidget {
  final String winnerName;
  final String winnerAvatarId;
  final int votesReceived;
  final int totalScore;
  final bool isCurrentUserWinner;

  const FinalWinnerScreen({
    super.key,
    required this.winnerName,
    required this.winnerAvatarId,
    required this.votesReceived,
    required this.totalScore,
    this.isCurrentUserWinner = false,
  });

  @override
  State<FinalWinnerScreen> createState() => _FinalWinnerScreenState();
}

class _FinalWinnerScreenState extends State<FinalWinnerScreen>
    with TickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;
  bool _showConfetti = false;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    GameTelemetryService.instance.transition('final_winner');

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _scaleController.forward();
    SoundService.celebration();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _showConfetti = true);
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Avatars.all.firstWhere(
      (a) => a.id == widget.winnerAvatarId,
      orElse: () => Avatars.all.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          _buildGradientBackground(),
          ConfettiWidget(isActive: _showConfetti),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    _buildTitle(),
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildAvatarSection(avatar),
                    const SizedBox(height: AppSpacing.xl),
                    _buildWinnerName(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildStatsSection(),
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildButtons(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
          _buildOffScreenCard(avatar),
        ],
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withAlpha(51),
            const Color(0xFF111111),
            AppColors.gold.withAlpha(26),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      '🏆 BUFÓN DE LA NOCHE 🏆',
      style: AppTypography.h1.copyWith(
        color: AppColors.gold,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAvatarSection(Avatar avatar) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withAlpha(
                        (_glowAnimation.value * 255).toInt(),
                      ),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              );
            },
          ),
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.gold, AppColors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withAlpha(77),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(avatar.emoji, style: const TextStyle(fontSize: 96)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerName() {
    return Text(
      widget.winnerName,
      style: AppTypography.h1.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withAlpha(77), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Votos', '${widget.votesReceived}', Icons.favorite),
          Container(width: 1, height: 40, color: AppColors.border),
          _buildStatItem('Puntos', '${widget.totalScore}', Icons.stars),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.gold, size: 32),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.h2.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        if (widget.isCurrentUserWinner) ...[
          AnimatedPrimaryButton(
            text: _isSharing ? 'Generando...' : 'Compartir Victoria',
            onPressed: _isSharing ? null : _shareVictoryCard,
            icon: Icons.share,
            isLoading: _isSharing,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _exitToHome,
            icon: const Icon(Icons.home),
            label: const Text('Salir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOffScreenCard(Avatar avatar) {
    return Positioned(
      left: -10000,
      top: -10000,
      child: ShareVictoryCard(
        repaintKey: _cardKey,
        playerName: widget.winnerName,
        avatarId: widget.winnerAvatarId,
        votesReceived: widget.votesReceived,
        roundWins: widget.totalScore,
      ),
    );
  }

  Future<void> _shareVictoryCard() async {
    if (_isSharing) return;

    HapticService.mediumImpact();

    setState(() => _isSharing = true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final RenderRepaintBoundary boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Failed to generate image bytes');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/bufon_victory_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '¡Soy el Bufón de la Noche! 🏆');

      GameTelemetryService.instance.track(
        AppLogCategory.ui,
        'victory_card_shared',
        payload: {
          'votes_received': widget.votesReceived,
          'round_wins': widget.totalScore,
        },
      );

      if (mounted) {
        HapticService.success();
      }
    } catch (e, stackTrace) {
      // Sharing goes through the OS share sheet and can fail for reasons
      // outside the app (cancelled, no storage). Recorded as a warning so it
      // stays in the trail without counting as a bug.
      GameTelemetryService.instance.fail(
        AppLogCategory.ui,
        'victory_card_share_failed',
        error: e,
        stackTrace: stackTrace,
        severity: AppLogLevel.warning,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _exitToHome() {
    HapticService.lightImpact();
    context.pushAndRemoveAllFadeSlide(const HomeScreen());
  }
}

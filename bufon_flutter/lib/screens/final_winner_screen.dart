import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/game_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/bufon_phase.dart';
import '../core/theme/motion_tokens.dart';
import '../core/theme/reduced_motion.dart';
import '../models/avatar.dart';
import '../models/player.dart';
import '../presentation/transitions/keyhole_reveal_transition.dart';
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

/// The ceremony that ends a night of Bufón.
///
/// Fase 2B WP3 turns this from a result screen into the app's ceremonial
/// climax, using only systems that already existed:
///
/// - [BufonPhase.nightWinner] — the ceremonial register (Butter on Graphite),
///   which had no call site before this screen adopted it.
/// - [AppElevation.ceremonialGradient] — the one gradient Capítulo 3 ley 1
///   licenses outside a flat fill, written for this screen and unused until
///   now (it was reachable only through a button variant nobody called).
/// - [ConfettiTier.night] — the top rung of the celebration ladder, also
///   previously unused, so the night winner got exactly the same 50-particle
///   burst as a round winner.
/// - [KeyholeRevealTransition] — the brand's signature gesture, already
///   driving the round reveal. The winner's identity is the night's last
///   secret, so it opens through the same mask.
/// - [AppTypography.displayButter] — the canonical replacement for the
///   retired `displayGold`, documented as "ready for Fase 3F/3G when
///   Reveal/Winner screens migrate". This is that migration.
///
/// Nothing here is a new visual language: the retired `gold`, the casino red,
/// the hardcoded `#111111` and the three-stop red/gold gradient are gone, and
/// what replaces them is the same Butter/Graphite vocabulary the rest of the
/// app now speaks.
class FinalWinnerScreen extends StatefulWidget {
  final String winnerName;
  final String winnerAvatarId;
  final int votesReceived;
  final int totalScore;
  final bool isCurrentUserWinner;

  /// Final standings, highest score first. Optional because the data already
  /// exists at the only call site (`round_result_screen.dart` sorts the room's
  /// players to pick the winner) — passing it costs no query, no new model and
  /// no rule change. Empty means "no standings section", which keeps every
  /// other construction of this screen valid.
  final List<Player> standings;

  const FinalWinnerScreen({
    super.key,
    required this.winnerName,
    required this.winnerAvatarId,
    required this.votesReceived,
    required this.totalScore,
    this.isCurrentUserWinner = false,
    this.standings = const [],
  });

  @override
  State<FinalWinnerScreen> createState() => _FinalWinnerScreenState();
}

class _FinalWinnerScreenState extends State<FinalWinnerScreen>
    with TickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;

  /// The ceremony's stage, using the same vocabulary as the round reveal so
  /// the two moments read as one language:
  ///
  /// - **0 — anticipation.** The mark arrives, the copy withholds. Nothing on
  ///   screen names the winner.
  /// - **1 — winner reveal + celebration.** The name opens through the
  ///   keyhole, `celebration()` fires, night confetti starts.
  /// - **2 — standings + next actions.** Only now does the scoreboard arrive,
  ///   for the same reason the round reveal gates its own: a standings list
  ///   whose first row is the winner spoils the reveal above it.
  int _stage = 0;
  final List<Timer> _stageTimers = [];

  /// Arrival of the ceremonial mark (Capítulo 17, tier Dramática).
  late final AnimationController _arrivalController;
  late final Animation<double> _arrival;

  /// Drives the keyhole over the winner's name.
  late final AnimationController _keyholeController;
  late final CurvedAnimation _keyholeProgress;

  @override
  void initState() {
    super.initState();

    GameTelemetryService.instance.transition('final_winner');

    _arrivalController = AnimationController(
      duration: MotionDurations.revealStage,
      vsync: this,
    );
    // `BRAND PHYSICS`: an element arriving already "sprung" overshoots
    // slightly before settling. Replaces `Curves.elasticOut`, which the motion
    // audit flagged for overshooting well past the documented
    // `celebrationOvershoot` ceiling.
    _arrival = Tween<double>(begin: MotionScale.arriveFrom, end: 1.0).animate(
      CurvedAnimation(parent: _arrivalController, curve: MotionCurves.release),
    );

    _keyholeController = AnimationController(
      duration: MotionDurations.revealStage,
      vsync: this,
    );
    _keyholeProgress = CurvedAnimation(
      parent: _keyholeController,
      curve: MotionCurves.reveal,
    );

    _arrivalController.forward();
    SoundService.celebration();

    _stageTimers.add(
      Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _stage = 1);
        _keyholeController.forward();
        // The arrival haptic the audit found missing: the emotional peak of
        // the product was silent to the hand. Fired from the timer, not from
        // `build`, so a rebuild cannot repeat it.
        HapticService.celebration();
      }),
    );
    _stageTimers.add(
      Timer(const Duration(milliseconds: 1900), () {
        if (!mounted) return;
        setState(() => _stage = 2);
      }),
    );
  }

  @override
  void dispose() {
    for (final timer in _stageTimers) {
      timer.cancel();
    }
    _keyholeProgress.dispose();
    _keyholeController.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Avatars.all.firstWhere(
      (a) => a.id == widget.winnerAvatarId,
      orElse: () => Avatars.all.first,
    );

    // `context` sits above the PhaseScope this method returns, so the register
    // is named directly here; descendants read it through `context.phase`.
    const phase = BufonPhase.nightWinner;

    return PhaseScope(
      phase: phase,
      child: Scaffold(
        body: DecoratedBox(
          // The ceremonial layer, finally used by the screen it was written
          // for. Kept within the dark half of the Butter/Graphite pair on
          // purpose: a full-Butter top band would force Ink foregrounds at the
          // top of a *scrolling* surface and Paper foregrounds below it, so
          // the same text would change legibility as the player scrolls.
          // Butter carries the ceremony as the protagonist accent instead.
          decoration: BoxDecoration(
            gradient: AppElevation.ceremonialGradient(
              AppColors.graphite,
              AppColors.graphiteShade,
            ),
          ),
          child: Stack(
            // Without this the Stack shrink-wraps its scrolling child under
            // the Scaffold's loose constraints, so the ceremonial gradient
            // only paints behind the content instead of filling the screen.
            fit: StackFit.expand,
            children: [
              // Night tier: 90 particles over 4.5 s, against the round
              // winner's 50 over 3 s. Suppressed under reduced motion by
              // ConfettiWidget itself (Capítulo 28) — no second mechanism.
              ConfettiWidget(isActive: _stage >= 1, tier: ConfettiTier.night),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      _CeremonialCrest(
                        avatar: avatar,
                        arrival: _arrival,
                        stage: _stage,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _WinnerReveal(
                        winnerName: widget.winnerName,
                        stage: _stage,
                        keyholeProgress: _keyholeProgress,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _CeremonialStats(
                        votesReceived: widget.votesReceived,
                        totalScore: widget.totalScore,
                        stage: _stage,
                      ),

                      // THE GATE. The standings' first row is the winner, so
                      // showing them before the reveal would answer the
                      // question the reveal is still asking — the same defect
                      // the round reveal had until Fase 2A.
                      if (_stage >= 2 && widget.standings.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _FinalStandings(players: widget.standings),
                      ],

                      if (_stage >= 2) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _Arrive(child: _buildActions()),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
              // Mounted only once the name is out. Off-screen is not the same
              // as absent: at `left: -10000` the card is still in the widget
              // *and semantics* trees, so building it during anticipation put
              // the winner's name where a screen reader could reach it before
              // the reveal — the same class of leak the standings gate closes
              // visually. It is mounted a full stage before the share button
              // can be pressed, so `_cardKey` is always laid out in time.
              if (_stage >= 1) _buildOffScreenCard(avatar),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // Share is available to everyone in the room (blueprint G6). WP3 left
        // it winner-only because ungating changes *who can do what*; WP7 is
        // that work. Presentation-only: every viewer already holds the name,
        // votes and score the card renders, so nothing new is read. The text
        // that leaves the app is chosen by status — see [_shareVictoryCard].
        AnimatedPrimaryButton(
          text: _isSharing ? 'Generando...' : 'Compartir victoria',
          onPressed: _isSharing ? null : _shareVictoryCard,
          icon: Icons.share,
          isLoading: _isSharing,
        ),
        const SizedBox(height: AppSpacing.md),
        // Secondary by construction: outline, not fill, so the ceremony keeps
        // one primary action (Capítulo 3 ley 4).
        AnimatedPrimaryButton(
          text: 'Salir',
          onPressed: _exitToHome,
          icon: Icons.home,
          variant: PrimaryButtonVariant.outline,
          backgroundColor: AppColors.paper,
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

      // A non-winner must never post the winner's claim.
      await Share.shareXFiles(
        [XFile(file.path)],
        text: GameCopy.shareVictory(
          isWinner: widget.isCurrentUserWinner,
          winnerName: widget.winnerName,
        ),
      );

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
            content: const Text('No se pudo compartir. Inténtalo de nuevo.'),
            backgroundColor: AppColors.coralShade,
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
    // A retreat, not an advance (Capítulo 23). The night is over: this is the
    // player stepping out of the experience, so it fades rather than sliding
    // forward the way advancing a round does.
    context.pushAndRemoveAllFade(const HomeScreen());
  }
}

/// A fade-and-rise entrance for content that appears after the reveal has
/// landed. Same Arrive the round reveal's scoreboard uses, so the two screens
/// introduce late content identically.
class _Arrive extends StatelessWidget {
  final Widget child;

  const _Arrive({required this.child});

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;

    return TweenAnimationBuilder<double>(
      duration: MotionDurations.arrive,
      curve: MotionCurves.settle,
      tween: Tween(begin: 1.0, end: 0.0),
      builder: (context, value, child) => Opacity(
        opacity: 1 - value,
        child: Transform.translate(
          offset: Offset(0, value * AppSpacing.xl),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// The winner's avatar on the ceremonial ground, plus the label that frames
/// the moment without answering it.
class _CeremonialCrest extends StatelessWidget {
  final Avatar avatar;
  final Animation<double> arrival;
  final int stage;

  const _CeremonialCrest({
    required this.avatar,
    required this.arrival,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;

    return Column(
      children: [
        ScaleTransition(
          scale: context.motion<Animation<double>>(
            full: arrival,
            reduced: const AlwaysStoppedAnimation(1.0),
          ),
          child: Semantics(
            // The avatar is decorative repetition of the name announced
            // below; one label, not an emoji read aloud as a character.
            label: 'Avatar del Bufón de la noche',
            image: true,
            excludeSemantics: true,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: phase.accent,
                boxShadow: AppElevation.protagonistShadow(
                  phase.accent,
                  opacity: 0.35,
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ),
              child: Center(
                child: Text(avatar.emoji, style: const TextStyle(fontSize: 84)),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            'EL BUFÓN DE LA NOCHE',
            style: AppTypography.h4.copyWith(
              color: phase.onSurfaceMuted,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// The night's last secret, opening through the brand's own gesture.
class _WinnerReveal extends StatelessWidget {
  final String winnerName;
  final int stage;
  final Animation<double> keyholeProgress;

  const _WinnerReveal({
    required this.winnerName,
    required this.stage,
    required this.keyholeProgress,
  });

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;

    return AnimatedSwitcher(
      duration: MotionDurations.swap,
      switchInCurve: MotionCurves.settle,
      switchOutCurve: MotionCurves.settle,
      child: stage == 0
          ? Text(
              '...',
              key: const ValueKey('anticipation'),
              style: AppTypography.display.copyWith(
                color: phase.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            )
          : ClipRRect(
              key: ValueKey('winner-$winnerName'),
              borderRadius: AppShapes.borderRadiusMd,
              child: KeyholeRevealTransition(
                // Capítulo 28: the reduced path keeps the AnimatedSwitcher's
                // cross-fade and drops the mask.
                progress: context.motion<Animation<double>>(
                  full: keyholeProgress,
                  reduced: const AlwaysStoppedAnimation(1.0),
                ),
                backdropColor: AppColors.graphiteShade,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    winnerName,
                    // The canonical replacement for the retired
                    // `displayGold`. The accent is spent on the one word the
                    // whole night was building toward.
                    style: AppTypography.displayButter,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Votes and points, withheld until the name lands so nothing competes with
/// the reveal.
class _CeremonialStats extends StatelessWidget {
  final int votesReceived;
  final int totalScore;
  final int stage;

  const _CeremonialStats({
    required this.votesReceived,
    required this.totalScore,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    if (stage < 1) return const SizedBox(height: AppSpacing.xxl);

    final phase = context.phase;

    return _Arrive(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.graphitePlus1,
          borderRadius: AppShapes.borderRadiusLg,
          border: AppShapes.hairlineBorder(
            phase.accent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _stat(context, 'Votos', votesReceived),
            Container(
              width: AppShapes.borderWidthHairline,
              height: 40,
              color: phase.onSurface.withValues(alpha: 0.12),
            ),
            _stat(context, 'Puntos', totalScore),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value) {
    final phase = context.phase;

    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            '$value',
            style: AppTypography.tabular(
              AppTypography.h2,
            ).copyWith(color: phase.accent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.body2.copyWith(color: phase.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

/// How the night ended for everyone else. Secondary by construction: compact
/// rows, no card chrome, and it never precedes the reveal.
class _FinalStandings extends StatelessWidget {
  final List<Player> players;

  const _FinalStandings({required this.players});

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;

    return _Arrive(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Cómo terminó la noche',
              style: AppTypography.h4.copyWith(color: phase.onSurface),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < players.length; i++)
            _row(context, players[i], i + 1, isWinner: i == 0),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    Player player,
    int position, {
    required bool isWinner,
  }) {
    final phase = context.phase;

    return Semantics(
      label: 'Puesto $position, ${player.name}, ${player.score} puntos',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          // The winner's row is tinted, but position and score are stated in
          // text too — the standing never depends on colour alone.
          color: isWinner
              ? phase.accent.withValues(alpha: 0.14)
              : AppColors.graphitePlus1,
          borderRadius: AppShapes.borderRadiusMd,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$position',
                style: AppTypography.body1.copyWith(
                  color: isWinner ? phase.accent : phase.onSurfaceMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                player.name,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body1.copyWith(
                  color: phase.onSurface,
                  fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${player.score} pts',
              style: AppTypography.tabular(AppTypography.body1).copyWith(
                color: isWinner ? phase.accent : phase.onSurfaceMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

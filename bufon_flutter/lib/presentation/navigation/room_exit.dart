// presentation/navigation/room_exit.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_copy.dart';
import '../../providers/game_providers.dart';
import '../../screens/home_screen.dart';
import '../widgets/animated_primary_button.dart';
import '../widgets/bufon_feedback.dart';
import 'page_transitions.dart';

/// The one way out of a room.
///
/// WP25 / **R-11** — *"No route out of a failed room stream; no leave-room
/// affordance"*, which audit A found as **S-5** and the Blueprint found
/// independently as **P7** (duplicate work **D-2**). Audit A's wording:
/// *"Once a room stream fails, **no route out exists**: no back arrow, no
/// retry, no home button. The reviewer must force-quit."*
///
/// **Why this is one function and not four copies.** R-11's non-goal is that
/// *"leaving must not be able to corrupt room state"*, and the only way to
/// guarantee that across four screens is for all four to leave the same way.
/// The sequence below already existed twice — `game_screen` and
/// `lobby_screen` each had a private `_navigateToHomeWithMessage` — and
/// spreading it to voting and the round result would have made four copies of
/// a contract that has to be identical. This is that contract, written once.
///
/// It is **not** a navigation-architecture change: no router package, no
/// route table, no new transition. BP line 1037 forbids the first as part of
/// a visual release, and this obeys it.
class RoomExit {
  RoomExit._();

  /// Leaves the current room and returns to Home.
  ///
  /// Order matters and is deliberate:
  ///
  /// 1. **Stop the heartbeat first.** `ConnectionService.stopHeartbeat`
  ///    writes `isOnline: false` and clears the timer. Navigating first would
  ///    leave a timer beating against a room the player has left.
  /// 2. **Clear `roomCodeProvider`.** `roomStreamProvider` watches it and
  ///    collapses to `Stream.value(null)`, so the listener detaches instead
  ///    of feeding a disposed screen.
  /// 3. **Hand the message over before navigating.** `BufonFeedback` uses the
  ///    root messenger that `MaterialApp` owns, which lives *above* the
  ///    Navigator — so a message handed over now survives the retreat.
  ///    Scheduling it afterwards never worked: the route is disposed when the
  ///    transition completes, and the `mounted` guard the delayed callback
  ///    needed was already false.
  /// 4. **Retreat.** `pushAndRemoveAllFade` (Capítulo 23): leaving a room is
  ///    a retreat, not forward movement, and the stack is cleared so system
  ///    back cannot walk into a room the player has left.
  ///
  /// The player document is deliberately **not** deleted. Removal is
  /// `cleanupDisconnectedPlayers`' job, on the 20 s heartbeat window WP22's
  /// eligibility filtering depends on — deleting here would put a second,
  /// competing eviction path next to it. `isOnline: false` plus a stopped
  /// heartbeat is what makes the player ineligible immediately and evicted
  /// shortly after, which is the existing contract.
  static Future<void> toHome(
    BuildContext context,
    WidgetRef ref, {
    String? message,
  }) async {
    // Read before the first await: `ref` must not be used across an async gap
    // once the widget may have been disposed.
    final connectionService = ref.read(connectionServiceProvider);
    await connectionService.stopHeartbeat();

    ref.read(roomCodeProvider.notifier).state = null;

    if (!context.mounted) return;
    if (message != null) BufonFeedback.show(context, message);
    context.pushAndRemoveAllFade(const HomeScreen());
  }

  /// Asks before leaving, then leaves.
  ///
  /// The "deliberate" half of R-11's *"a deliberate leave-room affordance"*.
  /// Returns `true` when the player confirmed and the exit ran.
  static Future<bool> confirmAndLeave(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(GameCopy.leaveRoomTitle),
        content: const Text(GameCopy.leaveRoomBody),
        actions: [
          AnimatedPrimaryButton(
            text: GameCopy.leaveRoomStay,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            variant: PrimaryButtonVariant.outline,
          ),
          AnimatedPrimaryButton(
            text: GameCopy.leaveRoomConfirm,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;
    if (!context.mounted) return false;

    await toHome(context, ref);
    return true;
  }
}

/// Makes system back a *deliberate* leave rather than an accident.
///
/// WP25 / **R-11**. Every room screen is reached through `replaceFadeSlide`
/// or `pushAndRemoveAllFade`, so it is the root of its stack — and Android's
/// back gesture on a root route **pops the application** while the player's
/// document, their heartbeat and their room membership all stay alive. The
/// room then waits 20 s for someone who is not coming back.
///
/// `canPop: false` intercepts that, asks, and routes the answer through the
/// same [RoomExit.toHome] every other exit uses.
class RoomPopScope extends ConsumerWidget {
  const RoomPopScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        RoomExit.confirmAndLeave(context, ref);
      },
      child: child,
    );
  }
}

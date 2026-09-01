class GameCopy {
  GameCopy._();

  static String lobbyWaiting(int playersNeeded) {
    if (playersNeeded <= 0) return 'Ya casi empieza el caos.';
    if (playersNeeded == 1) return 'Falta 1 bufón para prender esto.';
    return 'Faltan $playersNeeded bufones para prender esto.';
  }

  static String answerProgress(int ready, int total) {
    final missing = total - ready;
    if (missing <= 0) return 'Todos soltaron su genialidad. Revelando...';
    if (missing == 1) return 'Falta 1 bufón por responder.';
    return 'Faltan $missing bufones por responder.';
  }

  static String answerWaiting(int ready, int total) {
    final variants = [
      'Alguien todavía está cocinando una estupidez.',
      'La mesa espera al más inspirado.',
      'No presionamos, pero sí estamos juzgando.',
    ];
    return variants[(ready + total) % variants.length];
  }

  static String voteProgress(int ready, int total) {
    final missing = total - ready;
    if (missing <= 0) return 'Votos cerrados. Contando el desastre...';
    if (missing == 1) return 'Falta 1 voto para el juicio final.';
    return 'Faltan $missing votos para el juicio final.';
  }

  static String voteWaiting(int ready, int total) {
    final variants = [
      'Los votos están entrando.',
      'El grupo está decidiendo a quién coronar.',
      'Aquí se separa el chiste fino del crimen social.',
    ];
    return variants[(ready + total) % variants.length];
  }

  // Placeholder voice copy (Capítulo 25/26). These are the *supporting*
  // lines — each call site supplies its own title, because only it knows
  // which noun failed or is missing. Deliberately free of technical detail:
  // the exception already reaches AppLogger/Crashlytics, and a player can do
  // nothing with a Firebase error code.
  static const placeholderEmpty = 'Todavía no hay nada por aquí.';
  static const placeholderError =
      'No se pudo cargar. Inténtalo de nuevo en un momento.';
  static const placeholderOffline =
      'Parece que no hay conexión. Revisa tu internet.';

  // WP25 / R-11 — the leave-room affordance. Leaving is deliberate, so it
  // asks; and it says what leaving costs, because a player who taps back by
  // reflex is not asking to abandon a game their friends are still in.
  static const backToHome = 'Volver al Inicio';

  static const leaveRoomTitle = '¿Salir de la sala?';
  static const leaveRoomBody =
      'Vas a dejar la partida y volver al inicio. Los demás siguen jugando '
      'sin ti.';
  static const leaveRoomStay = 'Me quedo';
  static const leaveRoomConfirm = 'Salir';

  // WP25 / R-12 — the copy audit A called accusatory.
  //
  // It used to read "La sala se cerró por desconexión", which blames the
  // player's connection for something else entirely: the room is deleted when
  // fewer than two active players remain (`cleanupDisconnectedPlayers`). A
  // reviewer who switched apps for twenty seconds was told their internet had
  // failed. This states what actually happened and does not accuse anyone.
  static const roomClosedTooFewPlayers =
      'La sala se cerró: quedaron muy pocos jugadores.';

  // WP25 / R-37 — the connectivity banner. `ConnectionService` has run since
  // launch with no UI at all, so a player whose heartbeat was failing had no
  // way to know it, and audit A H-2's confusion had no explanation on screen.
  static const connectionLost = 'Sin conexión. Reintentando...';

  // WP25 / R-23, the half that needs no external fact: say the requirement
  // *before* someone commits to creating a room. Audit A M-4 records the
  // absence as the closest thing to a procedural root cause in the
  // repository — "nothing tells the reviewer the game needs 3 people".
  static const playersRequired = 'Se juega de 3 a 8 personas, cada quien en su celular.';

  static const revealingAnswers = 'Revelando respuestas...';
  static const countingVotes = 'Contando votos...';
  static const nextRound = 'Siguiente ronda...';
  static const roundWinnerPrefix = 'El BUFÓN de la ronda es';

  /// The victory card's share text (blueprint G6 / Fase 2B WP7).
  ///
  /// The card is shareable by everyone in the room, not just the winner, so the
  /// text cannot be written in the winner's voice — whoever posts it is either
  /// claiming the title or reporting someone else's night, and the copy has to
  /// say which. One entry point rather than a ternary at the call site, so the
  /// distinction is testable without going through the OS share sheet.
  static String shareVictory({
    required bool isWinner,
    required String winnerName,
  }) => isWinner
      ? '¡Soy el Bufón de la Noche! 🏆'
      : '$winnerName es el Bufón de la Noche. 🏆';
}

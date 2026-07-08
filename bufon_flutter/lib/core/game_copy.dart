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

  static const revealingAnswers = 'Revelando respuestas...';
  static const countingVotes = 'Contando votos...';
  static const nextRound = 'Siguiente ronda...';
  static const roundWinnerPrefix = 'El BUFÓN de la ronda es';
}

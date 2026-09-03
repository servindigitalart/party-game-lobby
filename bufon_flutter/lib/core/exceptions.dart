// core/exceptions.dart

/// Base exception for all game-related errors
class GameException implements Exception {
  final String message;
  final String? code;

  GameException(this.message, {this.code});

  @override
  String toString() => 'GameException: $message';
}

/// Thrown when a voting operation fails
class VotingException extends GameException {
  VotingException(super.message, {super.code});

  @override
  String toString() => 'VotingException: $message';
}

/// Thrown when a room operation fails
class RoomException extends GameException {
  RoomException(super.message, {super.code});

  @override
  String toString() => 'RoomException: $message';
}

/// Thrown when player text is refused by the objectionable-content policy.
///
/// R-20 Package 1. Carries no category and quotes no term: a player is told
/// their text is not allowed, never which list it matched, and the moderation
/// internals never reach the UI.
class ContentRejectedException extends GameException {
  ContentRejectedException()
    : super('Content not allowed', code: 'CONTENT_NOT_ALLOWED');

  @override
  String toString() => 'ContentRejectedException: $message';
}

/// Thrown when monetization limits are reached
class MonetizationException extends GameException {
  MonetizationException(super.message, {super.code});

  @override
  String toString() => 'MonetizationException: $message';
}

/// Thrown when a progression operation fails
class ProgressionException extends GameException {
  ProgressionException(super.message, {super.code});

  @override
  String toString() => 'ProgressionException: $message';
}

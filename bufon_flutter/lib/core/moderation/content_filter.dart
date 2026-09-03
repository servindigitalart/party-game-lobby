// core/moderation/content_filter.dart

import 'package:flutter/foundation.dart';

import '../exceptions.dart';
import 'content_policy.dart';

/// The outcome of checking one piece of player text.
class ContentDecision {
  const ContentDecision.allowed() : category = null;
  const ContentDecision.blocked(ContentPolicyCategory this.category);

  /// Which policy category matched, or `null` when the text is allowed. Kept
  /// out of user-facing copy: a player is told their text is not allowed, not
  /// which list it hit.
  final ContentPolicyCategory? category;

  bool get isAllowed => category == null;
  bool get isBlocked => category != null;
}

/// Bufón's objectionable-content filter.
///
/// **This is not a profanity filter, and turning it into one would break the
/// product.** Bufón is a comedy game for adults among friends; ordinary
/// Spanish and English profanity, sexual jokes, slang, crude humour,
/// anatomical terms and non-targeted insults are **allowed by design**. The
/// filter exists for the three categories in [ContentPolicyCategory], each of
/// which is objectionable regardless of the sentence around it.
///
/// Everything contextual — threats, targeted harassment, explicit sexual
/// content, self-harm — is deliberately **out of scope here**. Those need a
/// target, an intent or a pattern that a word list cannot see, and they belong
/// to reporting and host removal. See `R20_CONTENT_POLICY_DECISION.md` §5.
///
/// **Rejection, never redaction.** A blocked input is refused whole. Nothing
/// is starred out, and the player's text is never mutated and persisted in a
/// sanitised form — they are told, and they rewrite it.
///
/// Pure, deterministic, offline. No network, no clock, no randomness, no
/// fuzzy, phonetic or edit-distance matching.
class ContentFilter {
  ContentFilter({ContentPolicy policy = ContentPolicy.production})
    : _terms = {
        for (final entry in policy.entries)
          _normalize(entry.key): entry.value,
      };

  /// Normalised term → category. Built once; the policy is compile-time data.
  final Map<String, ContentPolicyCategory> _terms;

  static ContentFilter _instance = ContentFilter();

  /// The filter every write path calls.
  static ContentFilter get instance => _instance;

  /// Test-only. The production policy ships empty, so a test that needs to
  /// prove the boundary *blocks* has to supply a policy of its own. Kept to a
  /// setter rather than threading the filter through five constructors, which
  /// would be a refactor this package has no business making.
  @visibleForTesting
  static set instance(ContentFilter filter) => _instance = filter;

  /// Test-only. Restores the shipped policy.
  @visibleForTesting
  static void resetInstance() => _instance = ContentFilter();

  /// `á é í ó ú ü` fold to their bare vowels. **`ñ` is preserved**, because it
  /// is a distinct letter in Spanish and folding it to `n` would both mangle
  /// words and manufacture matches.
  static const Map<String, String> _foldings = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ç': 'c',
  };

  /// The five approved substitutions, and only these five. No open-ended leet
  /// table: every addition widens the false-positive surface.
  static const Map<String, String> _digitSubstitutions = {
    '4': 'a',
    '1': 'i',
    '0': 'o',
    '3': 'e',
    r'$': 's',
  };

  /// Reduces text to the form terms are compared in.
  ///
  /// 1. lowercase;
  /// 2. fold accents, preserving `ñ`;
  /// 3. apply the five approved digit/symbol substitutions;
  /// 4. collapse runs of **three or more** identical letters to one —
  ///    three, not two, because Spanish legitimately doubles `ll`, `rr` and
  ///    `cc` (`llave`, `carro`, `acción`) and collapsing at two would mangle
  ///    real words into false positives;
  /// 5. split on anything that is not a letter, and rejoin with single
  ///    spaces, which is what makes matching boundary-aware.
  ///
  /// **Intra-token punctuation is deliberately not stripped.** It would catch
  /// `p-e-n-d-e-j-o`, but it is the highest false-positive mechanism available
  /// and the filter is explicitly not the last line of defence — reporting and
  /// host removal cover determined evasion. Accepting that a motivated evader
  /// succeeds is better than blocking ordinary players.
  static String _normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_foldings[char] ?? _digitSubstitutions[char] ?? char);
    }

    // Collapse runs of 3+ identical characters down to a single one.
    final collapsed = buffer.toString().replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (match) => match.group(1)!,
    );

    // Letters only — `ñ` included, digits already substituted or dropped.
    final tokens = collapsed
        .split(RegExp(r'[^a-zñ]+'))
        .where((token) => token.isNotEmpty);

    // Padded so a term can be located with its own boundaries on both sides,
    // and so multi-word phrases match without a second code path.
    return tokens.isEmpty ? '' : ' ${tokens.join(' ')} ';
  }

  /// Checks one piece of player text.
  ContentDecision evaluate(String input) {
    if (_terms.isEmpty) return const ContentDecision.allowed();

    final normalized = _normalize(input);
    if (normalized.isEmpty) return const ContentDecision.allowed();

    for (final entry in _terms.entries) {
      final term = entry.key;
      if (term.isEmpty) continue;
      if (normalized.contains(term)) {
        return ContentDecision.blocked(entry.value);
      }
    }
    return const ContentDecision.allowed();
  }

  /// Refuses [input] if the policy blocks it.
  ///
  /// Called at the persistence boundary rather than in a widget, so no caller
  /// can reach Firestore around it and no screen carries policy logic. Throws
  /// [ContentRejectedException], which the existing `GameException` handling
  /// already surfaces.
  void enforce(String input) {
    if (evaluate(input).isBlocked) throw ContentRejectedException();
  }
}

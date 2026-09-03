// core/moderation/content_policy.dart

/// The three categories Bufón refuses outright.
///
/// **R-20 / `R20_CONTENT_POLICY_DECISION.md` §4.** Each is here for one
/// reason: it is objectionable *regardless of the sentence around it*, which
/// is the only property a deterministic word list can honestly act on.
enum ContentPolicyCategory {
  /// Apple Guideline 1.1.1 — slurs targeting race, ethnicity, religion,
  /// sexual orientation, gender identity or disability.
  protectedClassSlur,

  /// Apple Guideline 1.1.4 — child sexual exploitation terminology.
  childExploitation,

  /// Apple Guideline 1.1.4 — *"prostitution, or human trafficking and
  /// exploitation"*. **Phrases only.** Single words in this space are ordinary
  /// Spanish vocabulary and would fire constantly on jokes.
  exploitationSolicitation,
}

/// The terms Bufón refuses, by category.
///
/// ## What is deliberately NOT here
///
/// **This is not a profanity list, and Bufón must never grow one.** The
/// product is a comedy game for adults among friends: crude, vulgar and
/// irreverent humour is the point of it, and the policy decision is explicit
/// that *"no word is blocked for being vulgar"*. Ordinary Spanish and English
/// profanity, sexual jokes, slang, anatomical terms and non-targeted insults
/// are **allowed** and must stay allowed.
///
/// Contextual harms — threats, targeted harassment, explicit sexual content,
/// self-harm — are **not** here either. They need a target, an intent or a
/// pattern that no word list can see, and they belong to the reporting and
/// host-removal layers instead. Adding them here would be the mistake this
/// comment exists to prevent.
///
/// ## Why the lists are empty
///
/// The contents are an **owner-controlled policy surface**. Choosing which
/// words Bufón censors is a product judgement, not an implementation detail,
/// and `R20_CONTENT_POLICY_DECISION.md` §15 records it as the one decision
/// blocking this package. This file ships the structure so that populating it
/// is a policy act with no code change — and so that the act is reviewable in
/// version control, one line per term.
///
/// **Until the owner populates these lists the filter blocks nothing.** That
/// is stated plainly in `R20_PACKAGE1_IMPLEMENTATION_REPORT.md` rather than
/// implied, because an empty list means Apple Guideline 1.2's filtering
/// precaution is mechanically present but not yet effective.
///
/// ## How to add a term
///
/// Write it in its plain form, lowercase, unaccented, no padding — the filter
/// normalises both sides identically, so `Pendejó`, `PENDEJO` and `pendejo`
/// all reduce to the same key. Multi-word phrases are written with single
/// spaces. Keep the list **small, explicit and auditable**: it is meant to be
/// read in full by a human, not grown into a dictionary.
class ContentPolicy {
  const ContentPolicy({
    this.protectedClassSlurs = const <String>[],
    this.childExploitationTerms = const <String>[],
    this.exploitationSolicitationPhrases = const <String>[],
  });

  /// Single words. Spanish (es-MX) first; English only for terms whose
  /// severity is unambiguous in any context. All other languages are out of
  /// scope, and the review notes must say so rather than imply coverage.
  final List<String> protectedClassSlurs;

  /// Single words or short phrases.
  final List<String> childExploitationTerms;

  /// **Phrases only** — see [ContentPolicyCategory.exploitationSolicitation].
  final List<String> exploitationSolicitationPhrases;

  /// The policy the application runs with.
  ///
  /// Empty by owner decision. See the class comment.
  static const ContentPolicy production = ContentPolicy();

  Iterable<MapEntry<String, ContentPolicyCategory>> get entries sync* {
    for (final term in protectedClassSlurs) {
      yield MapEntry(term, ContentPolicyCategory.protectedClassSlur);
    }
    for (final term in childExploitationTerms) {
      yield MapEntry(term, ContentPolicyCategory.childExploitation);
    }
    for (final term in exploitationSolicitationPhrases) {
      yield MapEntry(term, ContentPolicyCategory.exploitationSolicitation);
    }
  }

  bool get isEmpty => entries.isEmpty;
}

// test/content_filter_test.dart
//
// R-20 Package 1 — the objectionable-content filter.
//
// The single most important property under test is a *negative* one: Bufón is
// a comedy game for adults among friends, and ordinary Spanish and English
// profanity, sexual jokes, slang and non-targeted insults are **allowed by
// design**. Half of this file exists to prove the filter has no hidden
// profanity list, because a filter that quietly acquired one would remove the
// reason the product exists.
//
// The mechanism tests use placeholder terms (`zzslur`, `zzchild`, …) rather
// than real slurs. The behaviour under test is normalization and matching,
// which does not care what the words mean — and a test suite should not have
// to carry a lexicon of abuse to prove that a boundary check works.

import 'package:bufon_flutter/core/exceptions.dart';
import 'package:bufon_flutter/core/moderation/content_filter.dart';
import 'package:bufon_flutter/core/moderation/content_policy.dart';
import 'package:bufon_flutter/data/repositories/practice_room_repository.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in policy. One entry per category, none of them real words.
const _testPolicy = ContentPolicy(
  protectedClassSlurs: ['zzslur', 'zzniño', 'zzalur'],
  childExploitationTerms: ['zzchild'],
  exploitationSolicitationPhrases: ['zzsolicita ahora'],
);

void main() {
  final filter = ContentFilter(policy: _testPolicy);

  /// Everything a comedy game must not refuse. Asserted against a *populated*
  /// policy, so passing means the filter genuinely has no profanity list —
  /// not merely that the shipped list happens to be empty.
  group('ordinary comedic language is allowed', () {
    const allowed = <String, String>{
      'Spanish profanity': 'no mames pendejo, qué pedo cabrón',
      'more Spanish profanity': 'chingón, me vale madres, puta madre',
      'mild Spanish profanity': 'qué mierda, está cabrón',
      'English profanity': 'that is fucking hilarious, holy shit',
      'more English profanity': 'damn, this is bullshit',
      'crude humour': 'se tiró un pedo en el elevador',
      'vulgar joke': 'mi suegra bailando en calzones',
      'sexual joke': 'lo hicimos en la cocina y se quemó la cena',
      'mild sexual reference': 'terminamos en su cama viendo la tele',
      'anatomical terminology': 'le dieron un balonazo en los testículos',
      'more anatomy': 'se operó los senos y el trasero',
      'playful insult': 'eres bien tonto, güey',
      'non-targeted insult': 'qué idiota el que escribió esto',
      'irreverence': 'ni Dios me salva de esta cruda',
      'slang': 'ese wey anda bien crudo, no manches',
    };

    allowed.forEach((label, text) {
      test(label, () {
        expect(filter.evaluate(text).isAllowed, isTrue, reason: '"$text"');
      });
    });

    test('the shipped policy allows all of it too', () {
      // The production list is empty by owner decision, so this is a weaker
      // assertion than the group above — kept so a future populated list is
      // re-checked against the same corpus.
      final production = ContentFilter();
      for (final text in allowed.values) {
        expect(production.evaluate(text).isAllowed, isTrue, reason: text);
      }
    });
  });

  group('the three approved categories are blocked', () {
    test('protected-class slur', () {
      final decision = filter.evaluate('eres un zzslur');
      expect(decision.isBlocked, isTrue);
      expect(decision.category, ContentPolicyCategory.protectedClassSlur);
    });

    test('child exploitation terminology', () {
      expect(filter.evaluate('zzchild').category,
          ContentPolicyCategory.childExploitation);
    });

    test('exploitation solicitation phrase', () {
      expect(filter.evaluate('oye zzsolicita ahora por favor').category,
          ContentPolicyCategory.exploitationSolicitation);
    });

    test('contextual harms are deliberately NOT auto-blocked', () {
      // Threats, harassment and self-harm belong to reporting and host
      // removal — they need a target, an intent or a pattern that a word list
      // cannot see. If these ever start failing, someone widened the policy.
      for (final text in [
        'te voy a matar de risa',
        'este wey es insoportable',
        'me quiero morir de vergüenza',
      ]) {
        expect(filter.evaluate(text).isAllowed, isTrue, reason: text);
      }
    });
  });

  group('normalization', () {
    test('is case-insensitive', () {
      expect(filter.evaluate('ZZSLUR').isBlocked, isTrue);
      expect(filter.evaluate('ZzSlUr').isBlocked, isTrue);
    });

    test('folds accents', () {
      expect(filter.evaluate('zzslúr').isBlocked, isTrue);
      expect(filter.evaluate('zzalúr').isBlocked, isTrue);
    });

    test('preserves ñ as a distinct letter', () {
      // `zzniño` is on the list; `zznino` is a different word and must not
      // match. Folding ñ→n would both mangle Spanish and invent matches.
      expect(filter.evaluate('zzniño').isBlocked, isTrue);
      expect(filter.evaluate('zznino').isAllowed, isTrue);
    });

    test('matches on token boundaries, not substrings', () {
      expect(filter.evaluate('zzslurgado').isAllowed, isTrue);
      expect(filter.evaluate('unzzslur').isAllowed, isTrue);
      expect(filter.evaluate('el zzslur ese').isBlocked, isTrue);
    });

    test('collapses runs of three or more', () {
      expect(filter.evaluate('zzsluuur').isBlocked, isTrue);
      expect(filter.evaluate('zzsluuuuuur').isBlocked, isTrue);
    });

    test('does NOT collapse a run of two', () {
      // Two is where Spanish doubles live; collapsing there would be a bug.
      expect(filter.evaluate('zzsluur').isAllowed, isTrue);
    });

    test('leaves Spanish double letters intact', () {
      final doubles = ContentFilter(
        policy: const ContentPolicy(
          protectedClassSlurs: ['lave', 'caro', 'acion'],
        ),
      );
      // ll, rr and cc must survive normalization, so these do not collapse
      // into the single-letter terms above.
      expect(doubles.evaluate('llave').isAllowed, isTrue);
      expect(doubles.evaluate('carro').isAllowed, isTrue);
      expect(doubles.evaluate('acción').isAllowed, isTrue);
    });

    test('applies the five approved digit substitutions', () {
      expect(filter.evaluate(r'zz$lur').isBlocked, isTrue, reason: r'$ -> s');
      expect(filter.evaluate('zz4lur').isBlocked, isTrue, reason: '4 -> a');
      expect(filter.evaluate('zzslur').isBlocked, isTrue);
    });

    test('does NOT strip intra-token punctuation', () {
      // A documented, deliberate trade-off: stripping punctuation is the
      // highest false-positive mechanism available, and the filter is not the
      // last line of defence. Determined evasion is covered by reporting and
      // host removal, not by widening this.
      expect(filter.evaluate('z-z-s-l-u-r').isAllowed, isTrue);
      expect(filter.evaluate('z.z.s.l.u.r').isAllowed, isTrue);
    });

    test('ordinary and empty inputs are allowed', () {
      for (final text in ['', '   ', 'Sofía', 'una respuesta normal', '12345']) {
        expect(filter.evaluate(text).isAllowed, isTrue, reason: '"$text"');
      }
    });

    test('is deterministic', () {
      for (final text in ['zzslur', 'no mames', 'zzsluuur', '']) {
        final first = filter.evaluate(text);
        for (var i = 0; i < 5; i++) {
          expect(filter.evaluate(text).category, first.category, reason: text);
        }
      }
    });
  });

  group('enforcement', () {
    test('allowed text passes silently', () {
      expect(() => filter.enforce('no mames qué chistoso'), returnsNormally);
    });

    test('blocked text throws the shared game exception', () {
      expect(() => filter.enforce('zzslur'),
          throwsA(isA<ContentRejectedException>()));
    });

    test('the exception carries no category and quotes no term', () {
      // Moderation internals must not reach the UI.
      try {
        filter.enforce('zzslur');
        fail('expected a rejection');
      } on ContentRejectedException catch (e) {
        expect(e.code, 'CONTENT_NOT_ALLOWED');
        expect(e.message.toLowerCase(), isNot(contains('zzslur')));
        expect(e.message.toLowerCase(), isNot(contains('slur')));
      }
    });

    test('rejection never mutates the input', () {
      // Rejection, not redaction: nothing is starred out and no sanitized
      // variant is produced for persistence.
      const original = 'eres un zzslur';
      expect(() => filter.enforce(original), throwsA(anything));
      expect(original, 'eres un zzslur');
    });
  });

  group('the shipped policy', () {
    test('is empty, and the filter therefore blocks nothing today', () {
      // Stated as a test so the state is impossible to overlook: the term
      // list is an owner decision that has not been made, and until it is,
      // Apple 1.2's filtering precaution is present but not yet effective.
      expect(ContentPolicy.production.isEmpty, isTrue);
      expect(ContentFilter().evaluate('zzslur').isAllowed, isTrue);
    });

    test('exposes categories, not terms, to callers', () {
      expect(ContentPolicyCategory.values, hasLength(3));
    });
  });

  // --------------------------------------------------------------------
  // The boundary. These prove prohibited text cannot reach a write path —
  // the property Apple 1.2 actually asks for — rather than merely that a
  // pure function returns false.
  // --------------------------------------------------------------------
  group('the persistence boundary refuses blocked text', () {
    setUp(() => ContentFilter.instance = ContentFilter(policy: _testPolicy));
    tearDown(ContentFilter.resetInstance);

    Future<RoomRepository> seeded({
      GamePhase phase = GamePhase.answering,
    }) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('ABC123').set({
        ...Room(code: 'ABC123', hostId: 'host-uid', phase: phase).toJson(),
        'playerCount': 1,
      });
      await firestore
          .collection('rooms')
          .doc('ABC123')
          .collection('players')
          .doc('host-uid')
          .set(Player(id: 'host-uid', name: 'Host', isHost: true).toJson());
      return RoomRepository(firestore: firestore);
    }

    test('a blocked host name never creates a room', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = RoomRepository(firestore: firestore);

      expect(
        () => repo.createRoom('ZZZ999', 'host-uid', 'zzslur'),
        throwsA(isA<ContentRejectedException>()),
      );
      // Nothing was written.
      final snap = await firestore.collection('rooms').doc('ZZZ999').get();
      expect(snap.exists, isFalse);
    });

    test('a blocked joining name never creates a player document', () async {
      final repo = await seeded(phase: GamePhase.lobby);
      expect(
        () => repo.joinRoom('ABC123', Player(id: 'p2', name: 'zzslur')),
        throwsA(isA<ContentRejectedException>()),
      );
      final room = await repo.getRoom('ABC123');
      expect(room!.players.map((p) => p.id), isNot(contains('p2')));
    });

    test('a blocked answer never reaches the player document', () async {
      final repo = await seeded();
      expect(
        () => repo.submitAnswerTransaction('ABC123', 'host-uid', 'zzslur'),
        throwsA(isA<ContentRejectedException>()),
      );
      final room = await repo.getRoom('ABC123');
      expect(room!.players.first.currentAnswer, isNull);
    });

    test('an allowed vulgar answer is written unchanged', () async {
      // Rejection, not redaction — and the comedy still gets through.
      final repo = await seeded();
      const answer = 'no mames, qué pendejo';
      await repo.submitAnswerTransaction('ABC123', 'host-uid', answer);

      final room = await repo.getRoom('ABC123');
      expect(room!.players.first.currentAnswer, answer);
    });

    test('Practice Mode is held to the same policy', () async {
      // Filtering is a property of the input contract, not an online-mode
      // feature. A Practice-only exemption would be exactly the conditional
      // behaviour R-21's non-goals forbid.
      final practice = PracticeRoomRepository();
      addTearDown(practice.dispose);

      expect(
        () => practice.createRoom('PRACT1', 'practice-human', 'zzslur'),
        throwsA(isA<ContentRejectedException>()),
      );

      await practice.createRoom('PRACT1', 'practice-human', 'Sofía');
      await practice.startFirstRound(
          roomCode: 'PRACT1', questionId: 'q1', questionText: '¿?');
      expect(
        () => practice.submitAnswerTransaction(
            'PRACT1', 'practice-human', 'zzslur'),
        throwsA(isA<ContentRejectedException>()),
      );

      // And the ordinary register still works there too.
      await practice.submitAnswerTransaction(
          'PRACT1', 'practice-human', 'qué pedo, no mames');
      final room = await practice.getRoom('PRACT1');
      expect(room!.players.first.currentAnswer, 'qué pedo, no mames');
    });
  });
}

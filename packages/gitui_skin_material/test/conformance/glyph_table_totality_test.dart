/// The glyph table has to answer for EVERY role, and it has to answer with a
/// Phosphor mark rather than with something plausible.
///
/// `MaterialGlyphs.of` is written as `_glyphs[role]!` on purpose: a fallback
/// would hide a missing role behind a mark that looks fine. That makes a role
/// added to the contract without a matching entry a runtime crash at whichever
/// screen happens to draw it first, which is exactly the kind of failure that
/// reaches a user before it reaches a suite. This file turns it into a
/// compile-cheap test that names the offending member.
///
/// The variant tables get the same treatment from the other side. They are
/// SPARSE by design - 48 roles at the heavier stroke, 13 drawn solid, both
/// measured from the application's own census - so the thing worth asserting
/// is not that they are complete but that every entry they DO hold is the
/// same codepoint under a different font family. Phosphor encodes weight that
/// way, and a table that had drifted onto a different codepoint would draw a
/// different mark at a weight nobody asked for.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';

/// The three fonts Phosphor ships, and the package they travel in.
const Set<String> _families = <String>{
  'PhosphorRegular',
  'PhosphorBold',
  'PhosphorFill',
};
const String _package = 'phosphor_flutter';

void main() {
  group('the table answers for every role', () {
    test('every IconRole resolves to a Phosphor mark', () {
      for (final IconRole role in IconRole.values) {
        final IconData glyph = MaterialGlyphs.of(role);
        expect(
          _families.contains(glyph.fontFamily),
          isTrue,
          reason:
              'IconRole.${role.name} resolves to ${glyph.fontFamily}, which is '
              'not one of the three Phosphor weights this skin draws from.',
        );
        expect(glyph.fontPackage, _package, reason: role.name);
        expect(
          glyph.matchTextDirection,
          isTrue,
          reason:
              'Every entry in this table mirrors with the reading direction, '
              'so IconRole.${role.name} disagreeing with its neighbours is a '
              'hand edit rather than a regeneration.',
        );
      }
    });

    test('the ordinary mark is the ordinary weight, with one recorded '
        'exception', () {
      final List<String> solid = <String>[
        for (final IconRole role in IconRole.values)
          if (MaterialGlyphs.of(role).fontFamily != 'PhosphorRegular')
            role.name,
      ];
      expect(
        solid,
        <String>['updateAvailable'],
        reason:
            'The table is Phosphor Regular throughout except where a role\'s '
            'MEANING is a loud one. `updateAvailable` is that role and carries '
            'its reason at its entry: the shell toolbar drew the update signal '
            'solid while the twelve download ACTIONS beside it drew the same '
            'mark as an outline. A second exception appearing here is a weight '
            'that leaked into the table without a decision.',
      );
    });

    test('updateAvailable draws the very mark the shell drew', () {
      final IconData signal = MaterialGlyphs.of(IconRole.updateAvailable);
      expect(
        signal.codePoint,
        MaterialGlyphs.of(IconRole.downloadSimple).codePoint,
        reason:
            'PhosphorIconsFill.downloadSimple and PhosphorIconsRegular.'
            'downloadSimple share a codepoint and differ only by family, so '
            'the split role has to keep the codepoint and take the fill.',
      );
      expect(signal.fontFamily, 'PhosphorFill');
      expect(
        signal,
        isNot(MaterialGlyphs.of(IconRole.downloadSimple)),
        reason:
            'If these two ever resolve equal, the update signal and the Clone '
            'action in the same toolbar row are one mark again.',
      );
    });
  });

  group('the variant tables are the same marks at another weight', () {
    test('every heavier entry keeps its codepoint', () {
      for (final IconRole role in IconRole.values) {
        final IconData ordinary = MaterialGlyphs.of(role);
        final IconData heavier = MaterialGlyphs.boldOf(role);
        expect(
          heavier.codePoint,
          ordinary.codePoint,
          reason:
              'boldOf(IconRole.${role.name}) is a different MARK, not a '
              'different weight of the same one.',
        );
        expect(
          heavier.fontFamily == 'PhosphorBold' || heavier == ordinary,
          isTrue,
          reason:
              'boldOf(IconRole.${role.name}) neither answers with the bold '
              'font nor falls back to the ordinary mark.',
        );
      }
    });

    test('every solid entry keeps its codepoint', () {
      for (final IconRole role in IconRole.values) {
        final IconData ordinary = MaterialGlyphs.of(role);
        final IconData solid = MaterialGlyphs.filledOf(role);
        expect(solid.codePoint, ordinary.codePoint, reason: role.name);
        expect(
          solid.fontFamily == 'PhosphorFill' || solid == ordinary,
          isTrue,
          reason:
              'filledOf(IconRole.${role.name}) neither answers with the fill '
              'font nor falls back to the ordinary mark.',
        );
      }
    });

    test('the solid table still holds the three roles the application '
        'toggles', () {
      // The favourite star (repository_card.dart, repository_list_item.dart)
      // and the engaged filter funnel (tags_screen.dart) are the only marks
      // the application drew solid from a control STATE. If any of them ever
      // loses its entry, `MaterialGlyphs.filledOf` silently falls back and
      // three sites stop showing that they are on.
      for (final IconRole role in <IconRole>[IconRole.star, IconRole.funnel]) {
        expect(
          MaterialGlyphs.filledOf(role).fontFamily,
          'PhosphorFill',
          reason: 'IconRole.${role.name} lost its solid variant.',
        );
      }
    });
  });
}

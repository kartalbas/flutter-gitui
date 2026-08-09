/// The contrast check the component matrix sweep cannot perform: the
/// foreground and the background a component *resolves* for a given state,
/// compared directly.
///
/// ## Why a second contrast suite exists
///
/// component_matrix_a11y_test.dart runs `textContrastGuideline` over every
/// scene, and that guideline does not read a colour. It screenshots the frame,
/// takes the histogram of the pixels inside a text node's bounding box, splits
/// them at their mean lightness and reports the ratio between the most
/// frequent colour in each half (Flutter 3.44.4
/// packages/flutter_test/lib/src/accessibility.dart:684-717). Below a certain
/// glyph size the most frequent non-background pixel is the anti-aliased edge
/// rather than the glyph, so the same word in the same role on the same
/// surface is reported at 4.11, 2.23 and 1.43 : 1 at fourteen, thirteen and
/// twelve pixels. A measurement that returns three answers for one colour pair
/// cannot be tightened into a check for colour decisions.
///
/// This suite measures the pair instead, and it is what caught the three
/// dark-mode failures of #402 that the sweep reported as passing:
///
///   * the selected `BaseCard` label at 4.13 : 1,
///   * selected chip labels at 2.86 : 1,
///   * `BaseTextField`'s value text at 1.17 : 1.
///
/// All three are one defect: a selected state swaps the container for a tonal
/// colour, or a brightness swaps the surface, and the foreground keeps a role
/// chosen against the other one. git_colors_contrast_test.dart in this
/// directory has worked this way for the git palette since that palette had
/// the same bug; this is the same idea applied to the scheme roles the Base
/// components pair.
///
/// ## What is measured, and how
///
/// Nothing here names the colour a component *should* use. Each case pumps the
/// real component in the real theme, reads the colour the rendered text
/// actually carries and the colour of the container it is actually painted on,
/// and compares those two. A component that changes its mind about a role is
/// therefore still measured correctly, and a component that forgets to move
/// its foreground with its background fails no matter which role it forgot.
///
/// Three things make that claim hold rather than merely sound right:
///
///   * **Every slot, not the one that was fixed.** A row's badge and trailing
///     text sit on the same tile as its title, and the first version of this
///     suite measured only the title - while a trailing label on a selected
///     row was still at 4.13 : 1, the very number the suite reported as gone.
///     Glyphs are measured too, at SC 1.4.11's 3 : 1.
///   * **The container as it is composited, not as it was handed over.**
///     `Color.computeLuminance()` ignores alpha, and an identity card's
///     container is that identity washed to 10 %, so a case that reads the
///     decoration colour raw is measuring a colour nobody painted.
///   * **A census** at the bottom of this file, which reads the component
///     sources and fails when one of them paints a selection container that
///     nothing here measures.
///
/// ## What is not measured
///
/// * **Disabled states.** WCAG 2.1 SC 1.4.3 exempts inactive components, and
///   Material 3 draws them at 38 % deliberately; the matrix sweep names the
///   same exemption.
/// * **The nine non-default colour schemes.** Every case below runs in the
///   scheme the application ships with, in both brightnesses — the same
///   population the golden matrix and the matrix sweep render. The git palette
///   is swept across all ten because it is a fixed set of hexes that has to
///   survive every scheme; a scheme role paired with its own on-role is a
///   different kind of value, and holding the whole component layer to all ten
///   is a larger decision than this suite makes.
/// * **Call sites that name a colour of their own.** A `Text` whose style
///   spells `onSurface` out overrides whatever its container published, and no
///   measurement of the component can see that - the component is correct and
///   the screen is not. The Base layer's answer is to reuse `Base*Label`,
///   which takes the inherited colour; where a screen did name the role
///   (conflict_resolution_screen.dart, commit_list_item.dart) it was changed
///   to do so.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_card.dart';
import 'package:flutter_gitui/shared/components/base_filter_chip.dart';
import 'package:flutter_gitui/shared/components/base_label.dart';
import 'package:flutter_gitui/shared/components/base_list_item.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole, Tone;

import '../support/conformance_harness.dart';

/// The label every case renders, so one finder reaches the measured glyph run.
const String _label = 'Commit';

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

/// The colour the rendered text really carries, after `DefaultTextStyle`
/// propagation and after any per-state resolution the widget performs.
Color _foreground(WidgetTester tester, [String text = _label]) {
  final Color? color = tester
      .renderObject<RenderParagraph>(find.text(text))
      .text
      .style
      ?.color;
  expect(
    color,
    isNotNull,
    reason:
        'the text "$text" is painted with no explicit colour, so nothing here '
        'can say what contrast it has; give it a colour or stop measuring it',
  );
  return color!;
}

/// Asserts the pair clears [minRatio], naming both colours when it does not.
///
/// Both sides are taken as they are *composited*, not as they are specified.
/// [background] arrives already flattened from the container reads below, and
/// the foreground is flattened here, because a foreground carries alpha too:
/// Material 3 draws supporting text at `onSurface` at 70 %, which is a
/// different colour on screen from the `onSurface` the style names, and
/// judging the nominal one would report 17.15 : 1 where the user sees
/// 8.53 : 1.
void expectReadable(
  Color foreground,
  Color background, {
  required String component,
  required String state,
  required Brightness brightness,
  double minRatio = kWcagTextContrast,
}) {
  final Color painted = flattenedOver(foreground, background);
  final double ratio = wcagContrast(painted, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minRatio),
    reason:
        '$component ($state, ${brightness.name}) paints ${_hex(foreground)} on '
        '${_hex(background)}'
        '${foreground.a == 1.0 ? '' : ', compositing to ${_hex(painted)}'}: '
        '${ratio.toStringAsFixed(2)} : 1, under the '
        'required $minRatio : 1. The foreground has to follow the container '
        'this state paints - see readableForeground in '
        'lib/shared/theme/contrast.dart.',
  );
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

/// The colour the row's [IconTheme] hands a glyph that names none of its own.
Color _iconForeground(WidgetTester tester, IconData icon) {
  final Color? color = IconTheme.of(tester.element(find.byIcon(icon))).color;
  expect(
    color,
    isNotNull,
    reason: 'no IconTheme in this tree gives $icon a colour at all',
  );
  return color!;
}

// ---------------------------------------------------------------------------
// Container reads
// ---------------------------------------------------------------------------
//
// Every read below ends in [flattenedOver]. A container colour taken off a
// decoration is the colour the widget was *given*, which is not always the
// colour on screen: `BaseCard.customBackgroundColor` arrives at 10 % alpha
// from both of its shipping call sites, and comparing a foreground against an
// unflattened tint measures a colour nobody painted - the very mistake that
// put black text on a near-black card. `wcagContrast` now asserts on a
// translucent argument, so a read that forgets this fails loudly rather than
// returning a comfortable number.

/// The opaque backdrop a component in this harness is composited over.
///
/// [pumpConformance] centres the component in a `Scaffold`, so what is behind
/// it is the scaffold's own background. That is deliberately *not* the colour
/// `BaseCard` assumes when it resolves a translucent container - it assumes
/// `surface`, because a card cannot know what it was placed on. Measuring the
/// backdrop that is really there keeps this suite from re-stating the
/// component's assumption back at it: if the two ever diverge far enough to
/// change an outcome, that divergence is the defect and this is where it
/// surfaces.
Color _backdrop(WidgetTester tester) => _theme(tester).scaffoldBackgroundColor;

/// BaseCard paints its container with the single `Container` under its root.
Color _cardContainer(WidgetTester tester) {
  final BoxDecoration decoration =
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(BaseCard),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;
  return flattenedOver(decoration.color!, _backdrop(tester));
}

/// BaseListItem paints its tile into the ancestor Material's ink layer, so the
/// tile colour is the `Ink` decoration's; an unselected row has none and the
/// surface behind it is what the text sits on.
Color _listItemContainer(WidgetTester tester) {
  final BoxDecoration decoration =
      tester
              .widget<Ink>(
                find
                    .descendant(
                      of: find.byType(BaseListItem),
                      matching: find.byType(Ink),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;
  final Color backdrop = _backdrop(tester);
  return flattenedOver(decoration.color ?? backdrop, backdrop);
}

/// A chip's fill, as the `Ink` inside `RawChip` paints it.
Color _chipContainer(WidgetTester tester) {
  final ShapeDecoration decoration =
      tester
              .widget<Ink>(
                find
                    .descendant(
                      of: find.byType(RawChip),
                      matching: find.byType(Ink),
                    )
                    .first,
              )
              .decoration!
          as ShapeDecoration;
  final Color backdrop = _backdrop(tester);
  return flattenedOver(decoration.color ?? backdrop, backdrop);
}

void main() {
  for (final Brightness brightness in <Brightness>[
    Brightness.light,
    Brightness.dark,
  ]) {
    final String mode = brightness.name;

    group('BaseCard ($mode)', () {
      // Every state the component offers, including the two the golden scene
      // renders side by side, so "selected" is never measured alone.
      for (final (String state, BaseCard card) in <(String, BaseCard)>[
        ('resting', const BaseCard(content: Text(_label))),
        ('selected', const BaseCard(content: Text(_label), isSelected: true)),
        (
          'selected, unfocused container',
          const BaseCard(
            content: Text(_label),
            isSelected: true,
            containerHasFocus: false,
          ),
        ),
        (
          'multi-selected',
          const BaseCard(content: Text(_label), isMultiSelected: true),
        ),
      ]) {
        testWidgets('$state content is readable on the container it paints', (
          WidgetTester tester,
        ) async {
          await pumpConformance(tester, card, brightness: brightness);
          expectReadable(
            _foreground(tester),
            _cardContainer(tester),
            component: 'BaseCard',
            state: state,
            brightness: brightness,
          );
        });
      }

      testWidgets('a Base label inside a selected card follows the card', (
        WidgetTester tester,
      ) async {
        // The composition every screen actually uses, and the one that made
        // the container fix insufficient on its own: a card's content is
        // `Base*Label`s, not raw `Text`, and a label that spells `onSurface`
        // out puts the unselected role straight back on the selected
        // container. Measuring only a bare `Text` would have certified a card
        // arrangement the application never renders.
        await pumpConformance(
          tester,
          const BaseCard(
            content: BaseLabel(_label, role: TextRole.body),
            isSelected: true,
          ),
          brightness: brightness,
        );
        expectReadable(
          _foreground(tester),
          _cardContainer(tester),
          component: 'BaseCard',
          state: 'selected, content is a body label',
          brightness: brightness,
        );
      });

      // A card that stands for an object with its own IDENTITY paints a
      // container the scheme never chose, and the rule has to hold for that
      // one too. The three cases below are the shipping ones, unchanged in
      // what they paint and changed only in how they are asked for: the card
      // no longer takes a `Color` at all — `customBackgroundColor` and
      // `customBorderColor` are gone with `BaseCard`'s hand-painting — so the
      // identity arrives as a `Tone` and the SKIN washes it, which is what
      // put the pairing and the fill on the same side of the seam at last.
      // `Tone.accent` is what repository_card.dart says for both of its
      // selections (the member draws `primary` for the single one and
      // `secondary` for a multi-selection); `Tone.series` is what
      // workspace_card.dart says, and index 0 is the same 0xFF2196F3 the
      // hand-painted case named.
      //
      // A translucent container is the case the rule got wrong, because
      // luminance ignores alpha: measured against its own channels, `primary`
      // at 10 % reads as a pale lilac in the dark theme and the card answered
      // black — on the near-black that tint actually composites to, 1.21 : 1.
      // The fourth case is the brightest ink the door still admits: series
      // index 6 is the palette's yellow, whose 10 % wash is the lightest
      // identity container a card can paint. What it is NOT is the old
      // opaque case's polarity: a 10 % wash over `surface` never gets light
      // enough to defeat `onSurface`, so no identity case can drive the
      // fallback's flip any more — that input became unreachable BY
      // CONSTRUCTION when the `Color` parameters left, because no member
      // washes an identity at full opacity. The flip itself does not go
      // unproven: the dark theme's tonal-selection cases above are the ones
      // that fire it (`onSecondaryContainer` misses 4.5 : 1 there, at
      // 4.45 : 1, and the rule departs from the M3 pairing). This case is
      // kept as the ceiling of what an identity may paint, not as the
      // polarity the contract no longer permits.
      for (final (String name, Tone tone, bool multi) in <(String, Tone, bool)>[
        ('repository card, selected: accent at 10%', Tone.accent, false),
        (
          'repository card, multi-selected: the second accent at 10%',
          Tone.accent,
          true,
        ),
        ('workspace card: a workspace colour at 10%', Tone.series(0), false),
        (
          'the lightest identity the series carries at 10%',
          Tone.series(6),
          false,
        ),
      ]) {
        testWidgets('an identity container is honoured too ($name)', (
          WidgetTester tester,
        ) async {
          await pumpConformance(
            tester,
            BaseCard(
              content: const BaseLabel(_label, role: TextRole.body),
              isSelected: !multi,
              isMultiSelected: multi,
              tone: tone,
            ),
            brightness: brightness,
          );
          expectReadable(
            _foreground(tester),
            _cardContainer(tester),
            component: 'BaseCard',
            state: 'selected with an identity container ($name)',
            brightness: brightness,
          );
        });
      }
    });

    group('BaseListItem ($mode)', () {
      for (final (String state, BaseListItem item) in <(String, BaseListItem)>[
        ('resting', const BaseListItem(content: Text(_label))),
        (
          'selected',
          const BaseListItem(content: Text(_label), isSelected: true),
        ),
        (
          'multi-selected',
          const BaseListItem(content: Text(_label), isMultiSelected: true),
        ),
      ]) {
        testWidgets('$state content is readable on the tile it paints', (
          WidgetTester tester,
        ) async {
          await pumpConformance(tester, item, brightness: brightness);
          expectReadable(
            _foreground(tester),
            _listItemContainer(tester),
            component: 'BaseListItem',
            state: state,
            brightness: brightness,
          );
        });
      }

      testWidgets('a Base label inside a selected row follows the row', (
        WidgetTester tester,
      ) async {
        // Same reason as the card above: every file row in the application
        // puts a `Base*Label` in its content slot.
        await pumpConformance(
          tester,
          const BaseListItem(
            content: BaseLabel(_label, role: TextRole.body),
            isSelected: true,
          ),
          brightness: brightness,
        );
        expectReadable(
          _foreground(tester),
          _listItemContainer(tester),
          component: 'BaseListItem',
          state: 'selected, content is a body label',
          brightness: brightness,
        );
      });

      // The row has four slots, not one, and they all sit on the same tile.
      // Measuring only `content` certified a component whose badge and
      // trailing text were still on the ambient `onSurface`: a label in the
      // trailing slot of a selected row measured 4.13 : 1 in the dark theme -
      // the exact number this suite was written to eliminate - because the
      // `DefaultTextStyle` wrapped `content` alone. Both slots are populated
      // here in one row, so the case is the row a file list really renders.
      for (final (String slot, String text) in <(String, String)>[
        ('badge', 'M'),
        ('trailing', 'HEAD'),
      ]) {
        testWidgets('a label in the $slot slot of a selected row follows the '
            'row', (WidgetTester tester) async {
          await pumpConformance(
            tester,
            const BaseListItem(
              content: BaseLabel(_label, role: TextRole.body),
              badge: BaseLabel('M', role: TextRole.detail),
              trailing: BaseLabel('HEAD', role: TextRole.body),
              isSelected: true,
            ),
            brightness: brightness,
          );
          expectReadable(
            _foreground(tester, text),
            _listItemContainer(tester),
            component: 'BaseListItem',
            state: 'selected, $slot slot',
            brightness: brightness,
          );
        });
      }

      // Glyphs are non-text UI, so the threshold is SC 1.4.11's 3 : 1 rather
      // than 4.5 : 1 - but the row's IconTheme has to follow the tile all the
      // same. It did not: `onSurfaceVariant` on the dark theme's selected tile
      // is 2.86 : 1, and the leading glyph of a selected row is a live case
      // (the command palette's rows are `leading: Icon(command.icon)` with no
      // colour of their own, lib/core/navigation/command_palette.dart:242).
      for (final (String state, bool selected, bool multi)
          in <(String, bool, bool)>[
            ('resting', false, false),
            ('selected', true, false),
            ('multi-selected', false, true),
          ]) {
        testWidgets('the $state row\'s icon theme follows the tile', (
          WidgetTester tester,
        ) async {
          await pumpConformance(
            tester,
            BaseListItem(
              leading: const Icon(Icons.folder),
              content: const BaseLabel(_label, role: TextRole.body),
              isSelected: selected,
              isMultiSelected: multi,
            ),
            brightness: brightness,
          );
          expectReadable(
            _iconForeground(tester, Icons.folder),
            _listItemContainer(tester),
            component: 'BaseListItem',
            state: '$state, leading glyph',
            brightness: brightness,
            minRatio: kWcagNonTextContrast,
          );
        });
      }
    });

    group('BaseFilterChip ($mode)', () {
      for (final bool selected in <bool>[false, true]) {
        testWidgets(
          '${selected ? 'selected' : 'unselected'} label is readable on the '
          'chip container',
          (WidgetTester tester) async {
            await pumpConformance(
              tester,
              BaseFilterChip(
                label: _label,
                selected: selected,
                onSelected: (bool _) {},
              ),
              brightness: brightness,
            );
            // A chip animates its selection, so the container is read on a
            // settled frame rather than mid-transition.
            await tester.pumpAndSettle();
            expectReadable(
              _foreground(tester),
              _chipContainer(tester),
              component: 'BaseFilterChip',
              state: selected ? 'selected' : 'unselected',
              brightness: brightness,
            );
          },
        );
      }
    });

    group('BaseChoiceGroup ($mode)', () {
      for (final bool selected in <bool>[false, true]) {
        testWidgets(
          '${selected ? 'chosen' : 'unchosen'} option is readable on the chip '
          'container',
          (WidgetTester tester) async {
            await pumpConformance(
              tester,
              BaseChoiceGroup<int>(
                options: const <ChoiceOption<int>>[
                  ChoiceOption<int>(value: 0, label: _label),
                ],
                selected: selected ? 0 : null,
                onSelected: (int _) {},
              ),
              brightness: brightness,
            );
            await tester.pumpAndSettle();
            expectReadable(
              _foreground(tester),
              _chipContainer(tester),
              component: 'BaseChoiceChip',
              state: selected ? 'chosen' : 'unchosen',
              brightness: brightness,
            );
          },
        );
      }
    });

    group('BaseTextField ($mode)', () {
      // The value, the resting label, the placeholder and the supporting text,
      // per variant, because the emphasized variant paints them on a filled
      // container and the other two on whatever surface the form sits on.
      for (final TextFieldVariant variant in TextFieldVariant.values) {
        testWidgets('${variant.name}: the value a user types is readable', (
          WidgetTester tester,
        ) async {
          await pumpConformance(
            tester,
            SizedBox(
              width: 260,
              child: BaseTextField(
                label: 'Branch name',
                variant: variant,
                initialValue: _label,
              ),
            ),
            brightness: brightness,
          );
          expectReadable(
            tester.widget<EditableText>(find.byType(EditableText)).style.color!,
            _fieldBackground(tester, variant),
            component: 'BaseTextField',
            state: '${variant.name}, value',
            brightness: brightness,
          );
        });

        testWidgets('${variant.name}: the placeholder is readable', (
          WidgetTester tester,
        ) async {
          await pumpConformance(
            tester,
            SizedBox(
              width: 260,
              child: BaseTextField(hintText: _label, variant: variant),
            ),
            brightness: brightness,
          );
          expectReadable(
            _foreground(tester),
            _fieldBackground(tester, variant),
            component: 'BaseTextField',
            state: '${variant.name}, placeholder',
            brightness: brightness,
          );
        });

        testWidgets('${variant.name}: the label and supporting text are '
            'readable', (WidgetTester tester) async {
          await pumpConformance(
            tester,
            SizedBox(
              width: 260,
              child: BaseTextField(
                label: _label,
                helperText: 'Lowercase, no spaces',
                variant: variant,
                initialValue: 'seeded',
              ),
            ),
            brightness: brightness,
          );
          final ColorScheme colors = _theme(tester).colorScheme;
          expectReadable(
            _foreground(tester),
            // The label floats above the field once it holds a value, so it
            // sits on the surface behind the field rather than on its fill.
            colors.surface,
            component: 'BaseTextField',
            state: '${variant.name}, label',
            brightness: brightness,
          );
          expectReadable(
            _foreground(tester, 'Lowercase, no spaces'),
            colors.surface,
            component: 'BaseTextField',
            state: '${variant.name}, supporting text',
            brightness: brightness,
          );
        });
      }
    });
  }

  // -------------------------------------------------------------------------
  // The census
  // -------------------------------------------------------------------------
  //
  // What separates a sweep from a long list is that its population is checked
  // against the source tree, the argument dialog_keyboard_contract_sweep_test
  // .dart makes for its dialogs. The defect this suite exists for has one
  // signature in source - a component that swaps its container for a selection
  // role - so the census looks for that signature rather than for a list
  // anybody maintains.

  group('the measured population', () {
    test('covers every component that paints a selection container', () {
      final List<String> uncovered = <String>[
        for (final String file in _selectionContainerComponents())
          if (!kMeasuredComponentSources.contains(file)) file,
      ];
      expect(
        uncovered,
        isEmpty,
        reason:
            'These components under lib/shared/components/ paint one of the '
            'Material 3 selection containers and no case in this file '
            'measures what they put on it. Add the cases and list the file in '
            'kMeasuredComponentSources. Both defects this suite was written '
            'for were exactly this shape, and both were found by reading the '
            'source rather than by anybody remembering the component existed.',
      );
    });

    test('names only files that still paint one', () {
      final Set<String> census = _selectionContainerComponents().toSet();
      final List<String> phantom = <String>[
        for (final String file in kMeasuredComponentSources)
          if (!census.contains(file)) file,
      ];
      expect(
        phantom,
        isEmpty,
        reason:
            'These files are listed as measured here but no longer paint a '
            'selection container, so the list and the source tree have '
            'drifted apart.',
      );
    });
  });
}

/// The component sources whose selection states this file measures.
///
/// Kept as paths rather than as types because the census below is a source
/// scan: the question it answers is "does this file paint a selection
/// container", and the answer has to be comparable with what is measured here.
/// `base_card.dart` left this list when it became a façade over
/// `surfaces.card`: it names neither selection role any more, because it paints
/// nothing at all — the containers, the pairing and the focus ring are the
/// skin's. The BaseCard cases above did NOT leave with it, and that is the
/// point of measuring the composed result rather than the source: they still
/// pump the real component in the real theme and still read the colour the
/// text actually carries on the container actually painted. What shrank is the
/// source-scan bookkeeping, which is what the second census test below exists
/// to force in the same change.
const Set<String> kMeasuredComponentSources = <String>{
  'lib/shared/components/base_list_item.dart',
};

/// Every file under `lib/shared/components/` that paints a Material 3
/// selection container, as slash-separated paths relative to the package root.
///
/// `secondaryContainer` and `tertiaryContainer` are the two roles this app
/// reserves for selection (base_card.dart and base_list_item.dart document the
/// convention), so naming either one is the signature of a component that has
/// a selected state with a foreground to get right.
///
/// The scan stops at the component layer on purpose. It is the layer the
/// golden matrix, the matrix a11y sweep and the component conformance suites
/// all take as their population, and it is where a `Base*` component is
/// supposed to live. `lib/shared/widgets/` holds compositions rather than
/// components - `base_tree_item.dart` there paints `primaryContainer` for its
/// selection and is measured by nothing here; that is a known boundary, not an
/// oversight, and moving the boundary means enrolling that layer in the whole
/// matrix rather than in this one file.
List<String> _selectionContainerComponents() {
  final Directory root = _applicationRoot();
  final Directory components = Directory('${root.path}/lib/shared/components');
  final RegExp pattern = RegExp(r'\b(secondaryContainer|tertiaryContainer)\b');
  final List<String> files = <String>[];
  for (final FileSystemEntity entity in components.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (!pattern.hasMatch(entity.readAsStringSync())) {
      continue;
    }
    files.add(
      entity.path.substring(root.path.length + 1).replaceAll(r'\', '/'),
    );
  }
  files.sort();
  return files;
}

/// The application package root: this package's own root (`packages/
/// gitui_skin_material/`) less the two directories that nest it, which is the
/// same `path: ../..` edge this package's pubspec declares its `flutter_gitui`
/// dependency with.
///
/// The census below scans the *application's* component sources. Since this
/// suite moved into the Material skin package (#408, #249 §5.1) the nearest
/// pubspec.yaml above it is this package's, so the plain package-root walk
/// would look for `lib/shared/components` inside a package that has no `lib/`.
Directory _applicationRoot() => _packageRoot().parent.parent;

/// The package root, found by walking up to the directory holding pubspec.yaml
/// — the same walk
/// packages/gitui_skin_material/test/conformance/support/deviation_register.dart
/// makes.
Directory _packageRoot() {
  Directory dir = Directory.current;
  for (int i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  throw StateError(
    'Could not locate the package root (pubspec.yaml) walking up from '
    '${Directory.current.path}.',
  );
}

/// The colour behind a field's own text: the filled variant paints a
/// container, the other two let the surface behind them show through.
Color _fieldBackground(WidgetTester tester, TextFieldVariant variant) {
  final ThemeData theme = _theme(tester);
  return variant == TextFieldVariant.emphasized
      ? WidgetStateProperty.resolveAs<Color?>(
              theme.inputDecorationTheme.fillColor,
              const <WidgetState>{},
            ) ??
            theme.colorScheme.surface
      : theme.colorScheme.surface;
}

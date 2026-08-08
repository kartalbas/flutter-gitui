/// The acceptance test for the icon half of the vocabulary conversion in the
/// `Base*` façade itself - `lib/shared/components/` and `lib/shared/widgets/`
/// (#249 P3a).
///
/// **The bar the conversion has to clear is that no glyph changes.** A button
/// that draws a trash mark today has to draw the same mark once its parameter
/// is an `IconRole` instead of an `IconData`, because the Material skin maps
/// the role back to the same Phosphor codepoint. That is checkable rather than
/// arguable, and it has to be checked mechanically: a role pointed at the
/// wrong glyph swaps one plausible mark for another, nothing throws, and the
/// first person to notice is a user.
///
/// This area is the one the whole phase turns on, and it is checked in three
/// independent ways because it can go wrong in three independent ways.
///
/// **One - the site still names the same mark.** [_kMarkCensus] is the
/// measured inventory of every glyph these twenty-five files named before the
/// conversion started, counted per file and per mark, with comments dropped.
/// The first test re-counts the same files, folding `PhosphorIcons*.x` and
/// `IconRole.x` into one tally because a converted site and an unconverted one
/// name the same *mark* under two vocabularies. A site that quietly moves from
/// `pencil` to `pencilSimple`, loses a mark or grows one fails here.
///
/// It is generated from `git show HEAD:<file>` rather than typed, and it
/// carries exactly **one** deliberate difference from the pre-conversion
/// count, recorded so that it cannot pass as an accident:
/// `searchable_dropdown.dart` drew its clear affordance with Material's
/// `Icons.clear`, which is not in the settled 151-name table at all; it had to
/// become a role for `BaseIconButton.icon` to accept it, and it became
/// `IconRole.x` because this application already answers "clear this field"
/// with `x` in `base_text_field.dart`. That is a judgement, it is the only one
/// in this area, and it is the reason the tally reads 80 references where the
/// pre-conversion tree read 79.
///
/// **Two - the skin maps the mark back to the identical glyph.** The second
/// test resolves every one of the 39 marks through `MaterialGlyphs` and
/// compares the resulting `IconData` field for field against this
/// application's own generated Phosphor constants. Identity means the
/// codepoint, the font family, the font package and `matchTextDirection` all
/// agree; a table answering with a different font family would render a
/// different-weight mark at the same codepoint and pass a codepoint-only
/// check.
///
/// **Three - the widget that ends up on screen carries that glyph.** The
/// tables can both be right and the façade can still hand the wrong thing to
/// the skin. The last group pumps each converted component with a known role
/// and reads the `Icon` that actually renders, which is the only check that
/// covers the wiring between the parameter and the member.
///
/// **Why the weight axis gets its own test.** `IconRole` deliberately carries
/// no weight - Phosphor's Regular/Bold/Fill, a Fluent filled variant and an SF
/// Symbol weight are not the same three things - so the weight is re-decided
/// inside the skin. Thirteen references in this area are drawn at Phosphor
/// Bold today and one control state is drawn at Fill; [_kDrawnHeavier] names
/// them, and the third test proves that `MaterialGlyphs.boldOf` and
/// `filledOf` hold the identical heavier codepoint AND that their answer
/// genuinely differs from `of`, so the heavier mark is available to the facet
/// that knows which slot it is filling rather than silently absent.
///
/// **What none of the three can see.** Check one folds the weights together so
/// that a converted and an unconverted site count the same; check three covers
/// only the components it pumps. Whether a particular SITE gave up its weight
/// is therefore measured elsewhere, over the whole of `lib/` rather than over
/// this area: `test/shared/icons/icon_weight_census_test.dart` counts every
/// Bold and Fill reference against a before-and-after ledger and requires each
/// difference to be named and dispositioned.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_icon.dart';
import 'package:flutter_gitui/shared/components/base_menu_item.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';

import '../../skin/pump_under_skin.dart';

void main() {
  test('every site in the Base* layer still names the same mark', () {
    final Map<String, Map<String, int>> found = <String, Map<String, int>>{};
    for (final String path in _kMarkCensus.keys) {
      final File file = File(_fromPackageRoot(path));
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '$path is in the icon census but no longer exists. If the file '
            'was renamed or deleted, move its marks in _kMarkCensus with it '
            'rather than dropping them: the census is what proves the '
            'conversion changed no glyph.',
      );
      found[path] = _marksIn(file.readAsStringSync());
    }

    expect(
      found,
      _kMarkCensus,
      reason:
          'The set of marks named by the Base* layer has moved. Both '
          'vocabularies are counted together, so this is not a report that a '
          'file has been converted - it is a report that a site now asks for '
          'a DIFFERENT mark than it did before. Every other area of the '
          'application passes its icons THROUGH these components, so a wrong '
          'role here is a wrong mark on every screen at once.',
    );
  });

  test('the census still accounts for all 80 references', () {
    // A cheap arithmetic backstop for the map comparison above. If somebody
    // edits the census to make a failure go away, the two numbers stop
    // agreeing and this says so in one line instead of an 80-entry diff.
    final int total = _kMarkCensus.values
        .expand((Map<String, int> marks) => marks.values)
        .fold(0, (int sum, int count) => sum + count);
    expect(total, 80);
    expect(_marksInCensus().length, 39);
  });

  test('the Material skin maps every one of those marks to the same glyph', () {
    final Map<String, _Glyph> phosphorRegular = _generatedGlyphs(
      'lib/shared/icons/phosphor_icons_regular.dart',
    );

    for (final String mark in _marksInCensus()) {
      final IconRole role = _roleNamed(mark);
      expect(
        phosphorRegular[mark],
        isNotNull,
        reason:
            'The Base* layer draws $mark today, but there is no '
            'PhosphorIconsRegular.$mark in the generated constants. The '
            'census and lib/shared/icons/ have drifted apart.',
      );
      expect(
        _Glyph.of(MaterialGlyphs.of(role)),
        phosphorRegular[mark],
        reason:
            'MaterialGlyphs.of(IconRole.$mark) is not the glyph '
            'PhosphorIconsRegular.$mark draws. Every converted call site in '
            'the application reaches its mark through this table, so a '
            'disagreement here is a silent icon change everywhere at once.',
      );
    }
  });

  test('the heavier strokes this area draws are still reachable', () {
    final Map<String, _Glyph> phosphorBold = _generatedGlyphs(
      'lib/shared/icons/phosphor_icons_bold.dart',
    );
    final Map<String, _Glyph> phosphorFill = _generatedGlyphs(
      'lib/shared/icons/phosphor_icons_fill.dart',
    );

    for (final MapEntry<String, String> entry in _kDrawnHeavier.entries) {
      final IconRole role = _roleNamed(entry.key);
      expect(
        _Glyph.of(MaterialGlyphs.boldOf(role)),
        phosphorBold[entry.key],
        reason:
            'MaterialGlyphs.boldOf(IconRole.${entry.key}) is not the glyph '
            'PhosphorIconsBold.${entry.key} draws, and ${entry.value} draws '
            'it. A role carries no weight by design, so the heavier stroke '
            'can only come back from this table.',
      );
      expect(
        MaterialGlyphs.boldOf(role),
        isNot(MaterialGlyphs.of(role)),
        reason:
            'MaterialGlyphs has no separate bold entry for IconRole.'
            '${entry.key}, so boldOf has fallen back to the ordinary stroke '
            'and ${entry.value} would be flattened when its surface is '
            'converted.',
      );
    }

    // The one solid mark this area's own components put on screen: a selected
    // `BaseIconButton` draws it, and `controls.iconButton` is what re-decides
    // the weight from `IconButtonSpec.selected`.
    for (final String mark in _kDrawnSolidWhenSelected) {
      final IconRole role = _roleNamed(mark);
      expect(_Glyph.of(MaterialGlyphs.filledOf(role)), phosphorFill[mark]);
      expect(MaterialGlyphs.filledOf(role), isNot(MaterialGlyphs.of(role)));
    }
  });

  group('the façade hands the skin the role, and the skin draws the glyph', () {
    testWidgets('BaseIcon draws the role at every scale', (
      WidgetTester tester,
    ) async {
      for (final ControlScale scale in ControlScale.values) {
        await pumpUnderSkin(
          tester,
          home: Scaffold(
            body: Center(child: BaseIcon(IconRole.gitBranch, scale: scale)),
          ),
        );
        await tester.pump();
        expect(
          _renderedGlyphs(tester),
          <IconData>[MaterialGlyphs.of(IconRole.gitBranch)],
          reason: 'BaseIcon at $scale drew something other than gitBranch',
        );
      }
    });

    testWidgets('BaseButton draws its leading and trailing roles', (
      WidgetTester tester,
    ) async {
      await pumpUnderSkin(
        tester,
        home: const Scaffold(
          body: Center(
            child: BaseButton(
              onPressed: _noop,
              label: 'Commit',
              leadingIcon: IconRole.check,
              trailingIcon: IconRole.caretDown,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_renderedGlyphs(tester), <IconData>[
        MaterialGlyphs.of(IconRole.check),
        MaterialGlyphs.of(IconRole.caretDown),
      ]);
    });

    testWidgets('BaseIconButton draws its role, and the solid one while '
        'selected', (WidgetTester tester) async {
      await pumpUnderSkin(
        tester,
        home: const Scaffold(
          body: Center(
            child: BaseIconButton(
              onPressed: _noop,
              icon: IconRole.star,
              tooltip: 'Favourite',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_renderedGlyphs(tester), <IconData>[
        MaterialGlyphs.of(IconRole.star),
      ]);

      await pumpUnderSkin(
        tester,
        home: const Scaffold(
          body: Center(
            child: BaseIconButton(
              onPressed: _noop,
              icon: IconRole.star,
              tooltip: 'Favourite',
              isSelected: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _renderedGlyphs(tester),
        <IconData>[MaterialGlyphs.filledOf(IconRole.star)],
        reason:
            'A favourited repository has always drawn a SOLID star. The role '
            'carries no weight, so the skin has to answer it from '
            'IconButtonSpec.selected; if this fails the star silently became '
            'an outline everywhere it is used.',
      );
    });

    testWidgets('BaseTextField draws its prefix role', (
      WidgetTester tester,
    ) async {
      await pumpUnderSkin(
        tester,
        home: const Scaffold(
          body: Center(
            child: BaseTextField(
              label: 'Branch',
              prefixIcon: IconRole.gitBranch,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_renderedGlyphs(tester), <IconData>[
        MaterialGlyphs.of(IconRole.gitBranch),
      ]);
    });

    testWidgets('MenuItemContent draws its leading role', (
      WidgetTester tester,
    ) async {
      await pumpUnderSkin(
        tester,
        home: const Scaffold(
          body: Center(
            child: MenuItemContent(icon: IconRole.trash, label: 'Delete'),
          ),
        ),
      );
      await tester.pump();
      expect(_renderedGlyphs(tester), <IconData>[
        MaterialGlyphs.of(IconRole.trash),
      ]);
    });
  });
}

void _noop() {}

/// Every glyph currently on screen, in the order the tree lays them out.
List<IconData> _renderedGlyphs(WidgetTester tester) => tester
    .widgetList<Icon>(find.byType(Icon))
    .map((Icon icon) => icon.icon!)
    .toList();

/// One glyph's identity, compared field for field.
///
/// The codepoint alone is not identity: Phosphor's three weights share every
/// codepoint and differ only in the font family, so a table that answered
/// `PhosphorRegular` where the application draws `PhosphorBold` would pass a
/// codepoint check while rendering a visibly different mark.
class _Glyph {
  const _Glyph(
    this.codePoint,
    this.fontFamily,
    this.fontPackage,
    this.matchTextDirection,
  );

  factory _Glyph.of(IconData icon) => _Glyph(
    icon.codePoint,
    icon.fontFamily,
    icon.fontPackage,
    icon.matchTextDirection,
  );

  final int codePoint;
  final String? fontFamily;
  final String? fontPackage;
  final bool matchTextDirection;

  @override
  bool operator ==(Object other) =>
      other is _Glyph &&
      other.codePoint == codePoint &&
      other.fontFamily == fontFamily &&
      other.fontPackage == fontPackage &&
      other.matchTextDirection == matchTextDirection;

  @override
  int get hashCode =>
      Object.hash(codePoint, fontFamily, fontPackage, matchTextDirection);

  @override
  String toString() =>
      'U+${codePoint.toRadixString(16)} in $fontFamily/$fontPackage'
      '${matchTextDirection ? ' (mirrored)' : ''}';
}

/// Every mark the census names, once each.
Set<String> _marksInCensus() =>
    _kMarkCensus.values.expand((Map<String, int> marks) => marks.keys).toSet();

/// The role that stands for [mark], with a failure that names the mark rather
/// than throwing a bare `ArgumentError` out of `byName`.
IconRole _roleNamed(String mark) {
  final IconRole? role = IconRole.values
      .where((IconRole candidate) => candidate.name == mark)
      .firstOrNull;
  expect(
    role,
    isNotNull,
    reason:
        'The Base* layer draws $mark and IconRole has no member for it. The '
        'mapping phase settled that all 151 marks the application uses have a '
        'role, so a gap here means either the census or the enum has moved '
        'and the conversion must stop until it is decided once.',
  );
  return role!;
}

/// Counts the marks a Dart source names, under either vocabulary.
///
/// Comment lines are dropped first, which matters more here than anywhere
/// else: every `Base*` component carries worked examples in its doc comment,
/// and those examples name marks the component does not draw.
Map<String, int> _marksIn(String source) {
  final Map<String, int> counts = <String, int>{};
  for (final RegExpMatch match in _kMarkReference.allMatches(
    _withoutComments(source),
  )) {
    final String mark = match.group(2)!;
    counts[mark] = (counts[mark] ?? 0) + 1;
  }
  return counts;
}

/// A reference to a mark, in either vocabulary.
final RegExp _kMarkReference = RegExp(
  r'(PhosphorIcons(?:Regular|Bold|Fill)|IconRole)\.([a-zA-Z0-9_]+)',
);

/// Drops block comments and whole-line comments.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .where((String line) {
      final String trimmed = line.trimLeft();
      return !trimmed.startsWith('//') && !trimmed.startsWith('*');
    })
    .join('\n');

/// Reads this application's generated Phosphor constants out of their source.
///
/// A source scan rather than a lookup table, for the reason the generated file
/// itself records: `phosphor_flutter` declares
/// `class PhosphorIconData extends IconData` and `IconData` is a final class,
/// so the package's Dart code cannot be imported at all, and the constants are
/// static fields that no Dart program can enumerate by name.
Map<String, _Glyph> _generatedGlyphs(String path) {
  final String source = File(_fromPackageRoot(path)).readAsStringSync();
  final Map<String, _Glyph> glyphs = <String, _Glyph>{};
  for (final RegExpMatch match in _kGeneratedConstant.allMatches(source)) {
    glyphs[match.group(1)!] = _Glyph(
      int.parse(match.group(2)!, radix: 16),
      match.group(3),
      match.group(4),
      match.group(5) == 'true',
    );
  }
  expect(
    glyphs,
    isNotEmpty,
    reason:
        'No constants were read out of $path. The generated file has changed '
        'shape and this test is no longer measuring anything.',
  );
  return glyphs;
}

/// One entry of `lib/shared/icons/phosphor_icons_*.dart`, which is generated
/// and therefore uniform enough to read with a pattern.
final RegExp _kGeneratedConstant = RegExp(
  r'static const IconData ([a-zA-Z0-9_]+) = IconData\(\s*'
  r'0x([0-9a-fA-F]+),\s*'
  r"fontFamily: '([^']+)',\s*"
  r"fontPackage: '([^']+)',\s*"
  r'matchTextDirection: (true|false),',
);

/// Resolves [relativePath] against the package root, walking up from the
/// current directory to the first pubspec.yaml, so the test runs the same from
/// the repository root and from a subdirectory.
String _fromPackageRoot(String relativePath) {
  Directory directory = Directory.current;
  while (true) {
    if (File('${directory.path}/pubspec.yaml').existsSync()) {
      return '${directory.path}/$relativePath';
    }
    final Directory parent = directory.parent;
    if (parent.path == directory.path) return relativePath;
    directory = parent;
  }
}

/// The references in this area that are drawn at Phosphor Bold, with what each
/// one is saying by being heavier.
///
/// They are listed because the conversion loses the weight at the seam by
/// design: the role names the mark and the SLOT decides the stroke. Every one
/// of these still names `PhosphorIconsBold` in the tree, and that is
/// deliberate - the member that would restore the stroke (`surfaces.tree` for
/// the file tree, `ToolbarPickerEntry` for the four switchers) is not wired
/// yet, so converting the site now would flatten the mark with nothing to
/// recover it from. The entries prove the table is ready for the day it is.
const Map<String, String> _kDrawnHeavier = <String, String>{
  'folder':
      'base_tree_item.dart and workspace_switcher.dart draw every mark in a '
      'dense surface heavier',
  'folderOpen': 'base_tree_item.dart draws an open folder heavier',
  'file': 'base_tree_item.dart draws a file heavier',
  'house': 'workspace_switcher.dart draws the default workspace heavier',
  'gitBranch': 'branch_switcher.dart draws the toolbar switcher heavier',
  'gitCommit': 'repository_switcher.dart draws the toolbar switcher heavier',
  'warning':
      'branch_switcher.dart draws the force-delete warning heavier, in a '
      'dialog row',
  'check':
      'language_selector.dart draws the tick beside the chosen language '
      'heavier',
};

/// The marks a control in this area draws SOLID while it is on.
///
/// Unlike the bold list, this one is live: `BaseIconButton` delegates to
/// `controls.iconButton`, which resolves `filledOf` when `selected` is true,
/// so the favourite star and the engaged filter keep the solid mark they have
/// always drawn. The widget test above renders it; this asserts the table
/// underneath it.
const List<String> _kDrawnSolidWhenSelected = <String>['star', 'funnel'];

/// Every mark named in `lib/shared/components/` and `lib/shared/widgets/`, per
/// file: 80 references over 39 distinct marks in 25 files.
///
/// Generated from `git show HEAD:<file>` at the commit the conversion started
/// from, with the single documented exception recorded at the top of this
/// file. The counts are per MARK and not per weight, because that is the axis
/// the conversion must not move.
const Map<String, Map<String, int>> _kMarkCensus = <String, Map<String, int>>{
  'lib/shared/components/base_dialog.dart': <String, int>{
    'question': 1,
    'warning': 1,
    'x': 1,
  },
  'lib/shared/components/base_diff_viewer.dart': <String, int>{
    'file': 1,
    'gitDiff': 1,
  },
  'lib/shared/components/base_dropdown.dart': <String, int>{
    'caretDown': 1,
    'caretUp': 1,
    'magnifyingGlass': 1,
  },
  'lib/shared/components/base_list_item.dart': <String, int>{
    'dotsThreeVertical': 1,
  },
  'lib/shared/components/base_panel.dart': <String, int>{
    'caretDown': 1,
    'caretUp': 1,
  },
  'lib/shared/components/base_select_all_button.dart': <String, int>{
    'checkSquare': 3,
    'square': 2,
  },
  'lib/shared/components/base_speed_dial.dart': <String, int>{
    'list': 1,
    'x': 1,
  },
  'lib/shared/components/base_text_field.dart': <String, int>{
    'eye': 1,
    'eyeSlash': 1,
    'x': 1,
  },
  'lib/shared/components/base_viewer_dialog.dart': <String, int>{'x': 1},
  'lib/shared/components/copyable_text.dart': <String, int>{
    'check': 1,
    'copy': 1,
  },
  'lib/shared/widgets/async_value_builder.dart': <String, int>{'file': 1},
  'lib/shared/widgets/base_tree_item.dart': <String, int>{
    'caretDown': 1,
    'caretRight': 1,
    'file': 1,
    'folder': 1,
    'folderOpen': 1,
  },
  'lib/shared/widgets/batch_operations_bar.dart': <String, int>{
    'checkSquare': 1,
    'x': 1,
  },
  'lib/shared/widgets/branch_switcher.dart': <String, int>{
    'gitBranch': 2,
    'lock': 1,
    'pencilSimple': 1,
    'trash': 4,
    'warning': 1,
  },
  'lib/shared/widgets/command_log_panel.dart': <String, int>{
    'caretDown': 1,
    'caretUp': 1,
    'checkCircle': 1,
    'copy': 1,
    'magnifyingGlass': 2,
    'terminal': 2,
    'trash': 1,
    'x': 1,
    'xCircle': 2,
  },
  'lib/shared/widgets/empty_state.dart': <String, int>{
    'arrowClockwise': 1,
    'folderOpen': 1,
    'plus': 1,
    'warningCircle': 1,
  },
  'lib/shared/widgets/inline_search_field.dart': <String, int>{
    'magnifyingGlass': 1,
  },
  'lib/shared/widgets/language_selector.dart': <String, int>{
    'check': 1,
    'globe': 2,
  },
  'lib/shared/widgets/overflow_action_bar.dart': <String, int>{
    'dotsThreeVertical': 1,
  },
  'lib/shared/widgets/progress_overlay.dart': <String, int>{
    'caretRight': 1,
    'circleNotch': 1,
  },
  'lib/shared/widgets/quick_settings_menu.dart': <String, int>{
    'desktop': 1,
    'gear': 2,
    'moon': 1,
    'sun': 1,
    'textAa': 1,
  },
  'lib/shared/widgets/repository_switcher.dart': <String, int>{'gitCommit': 2},
  'lib/shared/widgets/searchable_dropdown.dart': <String, int>{'x': 1},
  'lib/shared/widgets/standard_app_bar.dart': <String, int>{
    'arrowsClockwise': 1,
    'dotsThreeVertical': 1,
    'magnifyingGlass': 1,
  },
  'lib/shared/widgets/workspace_switcher.dart': <String, int>{
    'folder': 2,
    'house': 2,
  },
};

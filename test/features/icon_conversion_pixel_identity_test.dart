/// Proves the three icon endpoints converted in the first #249 P3a wave render
/// exactly what they rendered before the conversion.
///
/// The table test (`test/shared/icons/icon_role_glyph_identity_test.dart`)
/// pins that a role resolves to the same `IconData`; this file pins the other
/// half of "no glyph may change" for the endpoints that stopped constructing
/// `Icon(PhosphorIconsRegular.x)` themselves and started asking the skin: the
/// rendered widget must carry the same glyph at the same size in the same
/// colour. Each assertion below states the pre-conversion values measured at
/// the call site, so a later change to the skin's scale or tone mapping that
/// would silently restyle these marks fails here with the old numbers in the
/// message.
///
/// The three endpoints are the three conversion patterns this wave produced:
/// a section header asking for the accent tone at the prominent scale
/// (`SettingsSection`), a list row leaving colour to its enclosing row and
/// asking only for Material's default glyph size (`CommandPalette`), and a
/// dense detail row asking for the muted tone at the compact scale
/// (`StashListTile`, whose twin in `TagListTile` is the same code).
library;

import 'package:flutter/material.dart';
import 'package:flutter_gitui/core/git/models/stash.dart';
import 'package:flutter_gitui/core/navigation/command_palette.dart';
import 'package:flutter_gitui/features/settings/widgets/settings_section.dart';
import 'package:flutter_gitui/features/stashes/widgets/stash_list_tile.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;
import 'package:shared_preferences/shared_preferences.dart';

import '../skin/pump_under_skin.dart';

/// The first widget rendering [glyph], with a failure that names the glyph
/// rather than reporting an empty finder.
Icon _iconDrawing(WidgetTester tester, IconData glyph) {
  final Finder finder = find.byWidgetPredicate(
    (Widget widget) => widget is Icon && widget.icon == glyph,
  );
  expect(
    finder,
    findsWidgets,
    reason:
        'No Icon in the tree draws the glyph the site rendered before the '
        'conversion (U+${glyph.codePoint.toRadixString(16)}). The mark '
        'changed, which is the one thing this sub-phase promises cannot '
        'happen.',
  );
  return tester.widget<Icon>(finder.first);
}

void main() {
  testWidgets(
    'a settings section header still draws its mark at 24 in the accent '
    'colour, and its caret at 20 in the muted colour',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await pumpUnderSkin(
        tester,
        home: Scaffold(
          body: SettingsSection(
            title: 'Section under test',
            icon: IconRole.gear,
            children: const <Widget>[SizedBox.shrink()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ColorScheme scheme = Theme.of(
        tester.element(find.byType(SettingsSection)),
      ).colorScheme;

      // Before the conversion the header built
      // `Icon(widget.icon, size: AppTheme.iconL, color: colorScheme.primary)`,
      // which is 24 logical pixels in the accent colour.
      final Icon header = _iconDrawing(tester, PhosphorIconsRegular.gear);
      expect(header.size, 24);
      expect(header.color, scheme.primary);

      // And the expand caret built
      // `Icon(PhosphorIconsRegular.caretDown, size: AppTheme.iconM,
      // color: colorScheme.onSurfaceVariant)`: 20 logical pixels, muted.
      final Icon caret = _iconDrawing(tester, PhosphorIconsRegular.caretDown);
      expect(caret.size, 20);
      expect(caret.color, scheme.onSurfaceVariant);
    },
  );

  testWidgets(
    'a command palette row still draws its command mark at 24 with no colour '
    'of its own',
    (WidgetTester tester) async {
      await pumpUnderSkin(tester, home: const Scaffold(body: CommandPalette()));
      await tester.pumpAndSettle();

      // The first command in `GitCommands.all` is the clone command, whose
      // mark is [IconRole.downloadSimple]. Before the conversion the row
      // built a bare `Icon(command.icon)`: the ambient icon theme's 24
      // logical pixels, with the colour left to the row - `BaseListItem`
      // publishes it through an `IconTheme.merge` - so the widget itself must
      // still carry none.
      final Icon leading = _iconDrawing(
        tester,
        PhosphorIconsRegular.downloadSimple,
      );
      expect(leading.size, 24);
      expect(
        leading.color,
        isNull,
        reason:
            'The palette row never coloured its own mark - the row does. A '
            'colour here would overpaint the selected row state.',
      );
    },
  );

  testWidgets(
    'a stash detail row still draws its mark at 16 in the muted colour',
    (WidgetTester tester) async {
      const GitStash stash = GitStash(
        ref: 'stash@{0}',
        index: 0,
        hash: 'abcdef1234567890',
        branch: 'master',
        message: 'work in progress',
      );
      await pumpUnderSkin(
        tester,
        home: const Scaffold(body: StashListTile(stash: stash)),
      );
      await tester.pumpAndSettle();

      // The detail rows live inside the tile's expansion, so open it the way
      // a user would.
      await tester.tap(find.text('work in progress'));
      await tester.pumpAndSettle();

      final ColorScheme scheme = Theme.of(
        tester.element(find.byType(StashListTile)),
      ).colorScheme;

      // Before the conversion every detail row built
      // `Icon(icon, size: 16, color: colorScheme.onSurfaceVariant)`. The
      // commit row's mark is the one asserted because [IconRole.gitCommit]
      // appears nowhere else in the collapsed-plus-expanded tile.
      final Icon mark = _iconDrawing(tester, PhosphorIconsRegular.gitCommit);
      expect(mark.size, 16);
      expect(mark.color, scheme.onSurfaceVariant);
    },
  );
}

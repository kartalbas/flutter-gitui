// The two strengths of the roving highlight: while the owning collection
// holds keyboard focus a selected item wears its focus ring, and while focus
// lives elsewhere the ring disappears but the tinted background stays — the
// selection remains visible without claiming the keyboard.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_card.dart';
import 'package:flutter_gitui/shared/components/base_list_item.dart';
import 'package:flutter_gitui/shared/models/tree_node.dart';
import 'package:flutter_gitui/shared/widgets/base_tree_item.dart';

class _FileNode with TreeNodeMixin {
  @override
  String get name => 'file';

  @override
  String get fullPath => 'file';

  @override
  bool get isDirectory => false;

  @override
  List<TreeNodeMixin> get children => const [];

  @override
  bool isExpanded = false;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

BoxDecoration _decorationOf(WidgetTester tester, Finder scope) {
  final container = tester.widget<Container>(
    find.descendant(of: scope, matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

/// BaseListItem paints its tile with [Ink] rather than a [Container], so the
/// hover and press state layers land on top of the selection color instead of
/// under it (lib/shared/components/base_list_item.dart).
BoxDecoration _inkDecorationOf(WidgetTester tester, Finder scope) {
  final ink = tester.widget<Ink>(
    find.descendant(of: scope, matching: find.byType(Ink)).first,
  );
  return ink.decoration! as BoxDecoration;
}

void main() {
  testWidgets(
    'BaseListItem: ring border while focused, background-only while not',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              BaseListItem(isSelected: true, content: Text('focused')),
              BaseListItem(
                isSelected: true,
                containerHasFocus: false,
                content: Text('unfocused'),
              ),
            ],
          ),
        ),
      );

      final scheme = Theme.of(
        tester.element(find.byType(BaseListItem).first),
      ).colorScheme;

      final focused = _inkDecorationOf(
        tester,
        find.widgetWithText(BaseListItem, 'focused'),
      );
      expect(focused.color, scheme.secondaryContainer);
      expect(
        (focused.border! as Border).top.color,
        scheme.onSecondaryContainer,
      );

      final unfocused = _inkDecorationOf(
        tester,
        find.widgetWithText(BaseListItem, 'unfocused'),
      );
      expect(unfocused.color, scheme.secondaryContainer);
      expect(
        (unfocused.border! as Border).top.color,
        scheme.secondaryContainer,
        reason:
            'the muted state paints the ring in the background color so the '
            'row keeps its size but shows no ring',
      );
    },
  );

  testWidgets(
    'BaseTreeItem: foreground ring while focused, tinted row while not',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              BaseTreeItem(node: _FileNode(), depth: 0, isSelected: true),
              BaseTreeItem(
                node: _FileNode(),
                depth: 0,
                isSelected: true,
                containerHasFocus: false,
              ),
            ],
          ),
        ),
      );

      final containers = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(BaseTreeItem),
              matching: find.byType(Container),
            ),
          )
          .toList();

      final scheme = Theme.of(
        tester.element(find.byType(BaseTreeItem).first),
      ).colorScheme;

      final focused = containers.first;
      expect(
        (focused.decoration! as BoxDecoration).color,
        scheme.primaryContainer,
      );
      final ring = focused.foregroundDecoration! as BoxDecoration;
      expect((ring.border! as Border).top.color, scheme.onPrimaryContainer);

      final unfocused = containers.last;
      expect(
        (unfocused.decoration! as BoxDecoration).color,
        scheme.primaryContainer,
      );
      expect(unfocused.foregroundDecoration, isNull);
    },
  );

  testWidgets(
    'BaseCard: emphasized border while focused, resting outline while not',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              BaseCard(isSelected: true, content: Text('focused')),
              BaseCard(
                isSelected: true,
                containerHasFocus: false,
                content: Text('unfocused'),
              ),
            ],
          ),
        ),
      );

      final scheme = Theme.of(
        tester.element(find.byType(BaseCard).first),
      ).colorScheme;

      final focused = _decorationOf(
        tester,
        find.widgetWithText(BaseCard, 'focused'),
      );
      expect(
        (focused.border! as Border).top.color,
        scheme.onSecondaryContainer,
      );
      expect(focused.color, scheme.secondaryContainer);

      final unfocused = _decorationOf(
        tester,
        find.widgetWithText(BaseCard, 'unfocused'),
      );
      expect((unfocused.border! as Border).top.color, scheme.outlineVariant);
      expect(unfocused.color, scheme.secondaryContainer);
    },
  );
}

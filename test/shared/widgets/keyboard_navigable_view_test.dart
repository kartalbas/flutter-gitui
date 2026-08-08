// The navigable collections as the user experiences them: one Tab stop with a
// roving highlight driven by arrows/Home/End, Enter/Space activating the
// highlighted item, the trailing boundary reachable from the keyboard, key
// handling confined to the collection subtree, and additionalBindings
// rejected unless they use modified or function keys.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/controllers/item_navigation_controller.dart';
import 'package:flutter_gitui/shared/controllers/tree_view_controller.dart';
import 'package:flutter_gitui/shared/models/tree_node.dart';
import 'package:flutter_gitui/shared/widgets/keyboard_navigable_view.dart';
import '../../skin/pump_under_skin.dart';

/// Renders an item as "index|S|F" where S/F flag selection and container
/// focus, so every assertion reads a user-visible outcome off the tree.
Widget _marker(int index, bool isSelected, bool containerHasFocus) =>
    Text('$index|${isSelected ? 'S' : '-'}|${containerHasFocus ? 'F' : '-'}');

class _TreeNode with TreeNodeMixin {
  _TreeNode(this.name, {this.isDirectory = false, List<_TreeNode>? children})
    : children = children ?? [];

  @override
  final String name;

  @override
  String get fullPath => name;

  @override
  final bool isDirectory;

  @override
  final List<_TreeNode> children;

  @override
  bool isExpanded = true;
}

void main() {
  group('KeyboardNavigableListView', () {
    testWidgets('arrows rove the highlight and Enter activates the item', (
      tester,
    ) async {
      final activated = <int>[];
      final controller = ItemNavigationController(onActivate: activated.add);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          home: Scaffold(
            body: KeyboardNavigableListView(
              controller: controller,
              itemCount: 5,
              autofocus: true,
              itemBuilder: (context, index, isSelected, hasFocus) =>
                  _marker(index, isSelected, hasFocus),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('0|S|F'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('1|S|F'), findsOneWidget);
      expect(find.text('0|-|F'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activated, [1]);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(activated, [1, 1]);
    });

    testWidgets('End reaches the far edge and pushes the trailing boundary', (
      tester,
    ) async {
      var boundaryCalls = 0;
      final controller = ItemNavigationController(
        onTrailingBoundary: () => boundaryCalls++,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: KeyboardNavigableListView(
                controller: controller,
                itemCount: 50,
                itemExtent: 30,
                autofocus: true,
                itemBuilder: (context, index, isSelected, hasFocus) =>
                    _marker(index, isSelected, hasFocus),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // End jumps to the last item and the view scrolls it into the viewport.
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(find.text('49|S|F'), findsOneWidget);

      // End again is a push against the edge: the boundary hook, no move.
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(boundaryCalls, 1);

      // So is ArrowDown at the last item.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(boundaryCalls, 2);
      expect(find.text('49|S|F'), findsOneWidget);
    });

    testWidgets('the collection is one Tab stop and keys stay inside it', (
      tester,
    ) async {
      final before = FocusNode(debugLabel: 'before');
      final after = FocusNode(debugLabel: 'after');
      final controller = ItemNavigationController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          home: Scaffold(
            body: Column(
              children: [
                Focus(focusNode: before, child: const SizedBox.shrink()),
                SizedBox(
                  height: 200,
                  child: KeyboardNavigableListView(
                    controller: controller,
                    itemCount: 5,
                    itemBuilder: (context, index, isSelected, hasFocus) =>
                        _marker(index, isSelected, hasFocus),
                  ),
                ),
                Focus(focusNode: after, child: const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
      before.requestFocus();
      await tester.pump();

      // Tab enters the collection as a single stop...
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(controller.focusNode.hasPrimaryFocus, isTrue);

      // ...and one more Tab leaves it, past all five items.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);

      // With focus outside the collection its keys do nothing inside.
      controller.select(2);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(controller.selectedIndex, 2);
      expect(find.text('2|S|-'), findsOneWidget);
    });

    testWidgets('additionalBindings accept modified keys and fire scoped', (
      tester,
    ) async {
      var copies = 0;
      final controller = ItemNavigationController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          home: Scaffold(
            body: KeyboardNavigableListView(
              controller: controller,
              itemCount: 3,
              autofocus: true,
              additionalBindings: {
                const SingleActivator(
                  LogicalKeyboardKey.keyC,
                  control: true,
                ): () =>
                    copies++,
              },
              itemBuilder: (context, index, isSelected, hasFocus) =>
                  _marker(index, isSelected, hasFocus),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(copies, 1);
    });

    testWidgets('additionalBindings admit bare Delete and fire it', (
      tester,
    ) async {
      // Delete is not a navigation key, and the editable guard runs before
      // any binding, so a file tree may claim it bare — the established
      // desktop behaviour for deleting the focused entry.
      var deletes = 0;
      final controller = ItemNavigationController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          home: Scaffold(
            body: KeyboardNavigableListView(
              controller: controller,
              itemCount: 3,
              autofocus: true,
              additionalBindings: {
                const SingleActivator(LogicalKeyboardKey.delete): () =>
                    deletes++,
              },
              itemBuilder: (context, index, isSelected, hasFocus) =>
                  _marker(index, isSelected, hasFocus),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      expect(deletes, 1);
    });

    testWidgets('additionalBindings reject an unmodified letter key', (
      tester,
    ) async {
      final controller = ItemNavigationController();
      addTearDown(controller.dispose);

      expect(
        () => KeyboardNavigableListView(
          controller: controller,
          itemCount: 1,
          additionalBindings: {
            const SingleActivator(LogicalKeyboardKey.keyC): () {},
          },
          itemBuilder: (context, index, isSelected, hasFocus) =>
              _marker(index, isSelected, hasFocus),
        ),
        throwsAssertionError,
      );
    });
  });

  group('KeyboardNavigableGridView', () {
    testWidgets('arrows move by rows vertically and by items horizontally', (
      tester,
    ) async {
      var boundaryCalls = 0;
      final controller = ItemNavigationController(
        crossAxisCount: 3,
        onTrailingBoundary: () => boundaryCalls++,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          home: Scaffold(
            body: KeyboardNavigableGridView(
              controller: controller,
              itemCount: 8,
              autofocus: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (context, index, isSelected, hasFocus) =>
                  _marker(index, isSelected, hasFocus),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('0|S|F'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('3|S|F'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('4|S|F'), findsOneWidget);

      // Down from the middle column of the full row above the short last row
      // lands on the last item.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('7|S|F'), findsOneWidget);

      // Pushing right or down from the last item is the trailing boundary.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(boundaryCalls, 1);
      expect(find.text('7|S|F'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('6|S|F'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(find.text('3|S|F'), findsOneWidget);
    });
  });

  group('KeyboardNavigableTreeView', () {
    testWidgets('arrows walk rows, Left/Right fold, Enter fires the file', (
      tester,
    ) async {
      final toggled = <String>[];
      final controller = TreeViewController<_TreeNode>(
        onToggleNode: (node) => toggled.add(node.name),
      );
      addTearDown(controller.dispose);
      controller.updateNodes([
        _TreeNode(
          'dir-a',
          isDirectory: true,
          children: [_TreeNode('file-a1'), _TreeNode('file-a2')],
        ),
        _TreeNode('file-b'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          home: Scaffold(
            body: KeyboardNavigableTreeView<_TreeNode>(
              controller: controller,
              autofocus: true,
              itemBuilder: (context, node, depth, isSelected, hasFocus) => Text(
                '${node.name}|$depth|${isSelected ? 'S' : '-'}'
                '|${hasFocus ? 'F' : '-'}',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('dir-a|0|S|F'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('file-a1|0|S|F'), findsOneWidget);

      // Enter on a file fires the file action, not an expansion.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(toggled, ['file-a1']);

      // Up to the directory, Left collapses it: the children disappear.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.textContaining('file-a1'), findsNothing);
      expect(find.text('file-b|0|-|F'), findsOneWidget);

      // Right expands it again.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.textContaining('file-a1'), findsOneWidget);

      // End jumps to the last visible row.
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(find.text('file-b|0|S|F'), findsOneWidget);
    });
  });
}

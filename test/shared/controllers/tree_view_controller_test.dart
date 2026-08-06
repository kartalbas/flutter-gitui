// The tree controller's public contract as its two call sites use it, now
// served by the shared navigation core: navigateUp/Down walk the flattened
// rows (skipping directories when configured), the keyBindings map still
// drives the same actions, expansion reflattens while preserving selection,
// and Home/End arrived from the base without changing any of the above.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/controllers/tree_view_controller.dart';
import 'package:flutter_gitui/shared/models/tree_node.dart';

class _Node with TreeNodeMixin {
  _Node(this.name, {this.isDirectory = false, List<_Node>? children})
    : children = children ?? [];

  @override
  final String name;

  @override
  String get fullPath => name;

  @override
  final bool isDirectory;

  @override
  final List<_Node> children;

  @override
  bool isExpanded = true;
}

/// dir-a (expanded: file-a1, file-a2), file-b — flattened:
/// [dir-a, file-a1, file-a2, file-b]
List<_Node> _tree() => [
  _Node(
    'dir-a',
    isDirectory: true,
    children: [_Node('file-a1'), _Node('file-a2')],
  ),
  _Node('file-b'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('navigateDown walks the flattened rows and reports each node', () {
    final reported = <String?>[];
    final controller = TreeViewController<_Node>(
      onSelectionChanged: (node) => reported.add(node?.name),
    );
    addTearDown(controller.dispose);

    controller.updateNodes(_tree());
    expect(controller.selectedNode?.name, 'dir-a');

    controller.navigateDown();
    controller.navigateDown();
    expect(controller.selectedNode?.name, 'file-a2');
    expect(reported, ['file-a1', 'file-a2']);

    controller.navigateUp();
    expect(controller.selectedNode?.name, 'file-a1');
  });

  test('skipDirectories keeps the highlight off directory rows', () {
    final controller = TreeViewController<_Node>(skipDirectories: true);
    addTearDown(controller.dispose);

    controller.updateNodes(_tree());
    // Validation already skipped dir-a for the initial selection.
    expect(controller.selectedNode?.name, 'file-a1');

    controller.navigateDown();
    controller.navigateDown();
    expect(controller.selectedNode?.name, 'file-b');

    // Up from the first file: only a directory lies above, so no move.
    controller.navigateUp();
    controller.navigateUp();
    controller.navigateUp();
    expect(controller.selectedNode?.name, 'file-a1');
  });

  test('the keyBindings map still drives the same six actions', () {
    final controller = TreeViewController<_Node>();
    addTearDown(controller.dispose);
    controller.updateNodes(_tree());

    final bindings = controller.keyBindings;
    bindings[const SingleActivator(LogicalKeyboardKey.arrowDown)]!();
    expect(controller.selectedNode?.name, 'file-a1');
    bindings[const SingleActivator(LogicalKeyboardKey.arrowUp)]!();
    expect(controller.selectedNode?.name, 'dir-a');

    // Left on the expanded directory collapses it and hides its children.
    bindings[const SingleActivator(LogicalKeyboardKey.arrowLeft)]!();
    expect(controller.flattenedNodes.map((n) => n.name), ['dir-a', 'file-b']);

    // Right expands it again.
    bindings[const SingleActivator(LogicalKeyboardKey.arrowRight)]!();
    expect(controller.flattenedNodes.map((n) => n.name), [
      'dir-a',
      'file-a1',
      'file-a2',
      'file-b',
    ]);
  });

  test('Enter on a file row fires onToggleNode instead of expanding', () {
    final toggled = <String>[];
    final controller = TreeViewController<_Node>(
      onToggleNode: (node) => toggled.add(node.name),
    );
    addTearDown(controller.dispose);
    controller.updateNodes(_tree());

    controller.navigateDown(); // file-a1
    controller.toggleSelectedNode();
    expect(toggled, ['file-a1']);
    expect(controller.flattenedNodes.length, 4, reason: 'nothing collapsed');
  });

  test('collapsing above the selection moves it to the folded row', () {
    final reported = <String?>[];
    final controller = TreeViewController<_Node>(
      onSelectionChanged: (node) => reported.add(node?.name),
    );
    addTearDown(controller.dispose);

    final nodes = _tree();
    controller.updateNodes(nodes);
    controller.setSelectedIndex(2); // file-a2
    reported.clear();

    controller.toggleNodeExpansion(nodes.first); // collapse dir-a
    expect(controller.selectedNode?.name, 'dir-a');
    expect(reported, ['dir-a']);
  });

  test('selectByPath finds a row, null clears the selection', () {
    final controller = TreeViewController<_Node>();
    addTearDown(controller.dispose);
    controller.updateNodes(_tree());

    controller.selectByPath('file-b');
    expect(controller.selectedIndex, 3);
    expect(controller.isSelected(3), isTrue);

    controller.selectByPath(null);
    expect(controller.selectedIndex, -1);
    expect(controller.selectedNode, isNull);
  });

  test('Home and End arrived from the base and honour skipDirectories', () {
    final controller = TreeViewController<_Node>(skipDirectories: true);
    addTearDown(controller.dispose);
    controller.updateNodes(_tree());

    controller.moveToLast();
    expect(controller.selectedNode?.name, 'file-b');
    controller.moveToFirst();
    expect(
      controller.selectedNode?.name,
      'file-a1',
      reason: 'Home skips the leading directory row',
    );
  });
}

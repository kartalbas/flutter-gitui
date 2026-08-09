// A file row keeps the caret's place, so file names line up under the folders
// they hang under.
//
// The regression this pins was invisible for as long as the reservation was a
// NUMBER copied from the caret: the copy said 16 - the caret's glyph - while
// the caret itself measures its glyph plus the `Inset.hairline` it sits in, so
// files sat 4 px left of their folders and their rows stood a pixel shorter.
// The alignment is asserted rather than the widths, because what the tree owes
// the reader is the alignment and not any particular extent: a skin whose
// caret or whose hairline inset is a different size must still line the two
// columns up, and saying it this way is what lets the same expectations run
// under the blueprint at DISTANCE=64.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/models/tree_node.dart';
import 'package:flutter_gitui/shared/widgets/base_tree_item.dart';
import '../../skin/pump_under_skin.dart';

class _FileNode with TreeNodeMixin {
  @override
  String get name => 'file';

  @override
  String get fullPath => 'file';

  @override
  bool get isDirectory => false;

  @override
  List<TreeNodeMixin> get children => const <TreeNodeMixin>[];

  @override
  bool isExpanded = false;
}

class _DirNode with TreeNodeMixin {
  @override
  String get name => 'dir';

  @override
  String get fullPath => 'dir';

  @override
  bool get isDirectory => true;

  @override
  List<TreeNodeMixin> get children => const <TreeNodeMixin>[];

  @override
  bool isExpanded = false;
}

void main() {
  Future<void> pumpRows(WidgetTester tester) => pumpUnderSkin(
    tester,
    home: Scaffold(
      body: Column(
        children: <Widget>[
          BaseTreeItem(node: _DirNode(), depth: 0),
          BaseTreeItem(node: _FileNode(), depth: 0),
        ],
      ),
    ),
  );

  /// The node's own mark - the folder or file glyph - which is the first thing
  /// after the caret column and therefore where the misalignment showed.
  Finder markOf(Finder row) =>
      find.descendant(of: row, matching: find.byType(Icon)).last;

  testWidgets('a file mark starts where a folder mark starts', (tester) async {
    await pumpRows(tester);

    final Finder rows = find.byType(BaseTreeItem);
    final double folderMark =
        tester.getTopLeft(markOf(rows.at(0))).dx -
        tester.getTopLeft(rows.at(0)).dx;
    final double fileMark =
        tester.getTopLeft(markOf(rows.at(1))).dx -
        tester.getTopLeft(rows.at(1)).dx;

    expect(
      fileMark,
      folderMark,
      reason:
          'a file row reserves the caret it does not have, so its mark must '
          'begin exactly where a folder mark begins',
    );
  });

  testWidgets('a file row and a folder row stand the same height', (
    tester,
  ) async {
    await pumpRows(tester);

    final Finder rows = find.byType(BaseTreeItem);
    expect(
      tester.getSize(rows.at(1)).height,
      tester.getSize(rows.at(0)).height,
      reason:
          'the reserved caret is the caret, so a file row cannot be shorter '
          'than the folder row above it',
    );
  });

  testWidgets('the reserved caret is out of the hit test on a file row', (
    tester,
  ) async {
    var expandsToggled = 0;
    await pumpUnderSkin(
      tester,
      home: Scaffold(
        body: BaseTreeItem(
          node: _FileNode(),
          depth: 0,
          onExpandToggle: () => expandsToggled++,
        ),
      ),
    );

    // The point the caret would occupy if this row had one.
    final Offset rowStart = tester.getTopLeft(find.byType(BaseTreeItem));
    final Size rowSize = tester.getSize(find.byType(BaseTreeItem));
    await tester.tapAt(
      Offset(rowStart.dx + 20, rowStart.dy + rowSize.height / 2),
    );
    await tester.pump();

    expect(
      expandsToggled,
      0,
      reason:
          'a file has nothing to expand, so a click in the reserved column '
          'must reach the row rather than the hidden caret',
    );
  });
}

// The navigation semantics defined once: arrows move the roving highlight,
// Home/End jump to the edges, pushing past the last item fires the trailing
// boundary hook instead of moving, a grid moves by whole rows, and selection
// can live inside the controller or be delegated outward without the
// semantics changing.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/controllers/item_navigation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('internal selection, list semantics', () {
    late ItemNavigationController controller;
    late List<int> activated;
    late int boundaryCalls;
    late int notifications;

    setUp(() {
      activated = [];
      boundaryCalls = 0;
      notifications = 0;
      controller = ItemNavigationController(
        onActivate: activated.add,
        onTrailingBoundary: () => boundaryCalls++,
      );
      controller.itemCount = 5;
      controller.addListener(() => notifications++);
    });

    tearDown(() => controller.dispose());

    test('moving into an unselected list highlights the first item', () {
      expect(controller.selectedIndex, -1);
      controller.moveDown();
      expect(controller.selectedIndex, 0);

      controller.select(-1);
      controller.moveUp();
      expect(controller.selectedIndex, 0);
    });

    test('ArrowDown walks the list one item per press', () {
      controller.moveDown();
      controller.moveDown();
      controller.moveDown();
      expect(controller.selectedIndex, 2);
      expect(controller.isSelected(2), isTrue);
      expect(controller.isSelected(1), isFalse);
    });

    test(
      'ArrowDown at the last item fires the boundary once and does not move',
      () {
        controller.select(4);
        controller.moveDown();
        expect(controller.selectedIndex, 4);
        expect(boundaryCalls, 1);

        // Each further push is a further boundary event, never a move.
        controller.moveDown();
        expect(controller.selectedIndex, 4);
        expect(boundaryCalls, 2);
      },
    );

    test('the boundary never fires mid-list', () {
      controller.select(1);
      controller.moveDown();
      controller.moveDown();
      expect(controller.selectedIndex, 3);
      expect(boundaryCalls, 0);
    });

    test('ArrowUp at the first item stays put without any hook', () {
      controller.select(0);
      controller.moveUp();
      expect(controller.selectedIndex, 0);
      expect(boundaryCalls, 0);
    });

    test('Home jumps to the first item, End to the last', () {
      controller.select(2);
      controller.moveToFirst();
      expect(controller.selectedIndex, 0);
      controller.moveToLast();
      expect(controller.selectedIndex, 4);
      expect(boundaryCalls, 0);
    });

    test('End with the last item already highlighted fires the boundary', () {
      controller.select(4);
      controller.moveToLast();
      expect(controller.selectedIndex, 4);
      expect(boundaryCalls, 1);
    });

    test('activate fires for the highlighted item and only for one', () {
      controller.select(3);
      controller.activate();
      expect(activated, [3]);
    });

    test('activate with no highlight fires nothing', () {
      controller.activate();
      expect(activated, isEmpty);
    });

    test('select applies valid indices, ignores out-of-range ones', () {
      controller.select(3);
      expect(controller.selectedIndex, 3);
      controller.select(99);
      expect(controller.selectedIndex, 3);
      controller.select(-5);
      expect(controller.selectedIndex, 3);
      controller.select(-1);
      expect(controller.selectedIndex, -1);
    });

    test('every applied move notifies listeners exactly once', () {
      controller.moveDown();
      expect(notifications, 1);
      controller.moveDown();
      expect(notifications, 2);
      // A blocked move at the edge is not a change and must not notify.
      controller.select(4);
      final afterSelect = notifications;
      controller.moveDown();
      expect(notifications, afterSelect);
    });

    test('shrinking the collection clamps a dangling highlight', () {
      controller.select(4);
      controller.itemCount = 2;
      expect(controller.selectedIndex, 1);
      controller.itemCount = 0;
      expect(controller.selectedIndex, -1);
    });

    test('an empty collection ignores every move without hooks', () {
      controller.itemCount = 0;
      controller.moveDown();
      controller.moveUp();
      controller.moveToFirst();
      controller.moveToLast();
      controller.activate();
      expect(controller.selectedIndex, -1);
      expect(boundaryCalls, 0);
      expect(activated, isEmpty);
    });
  });

  group('grid arithmetic (3 columns, 8 items: last row is short)', () {
    late ItemNavigationController controller;
    late int boundaryCalls;

    setUp(() {
      boundaryCalls = 0;
      controller = ItemNavigationController(
        crossAxisCount: 3,
        onTrailingBoundary: () => boundaryCalls++,
      );
      controller.itemCount = 8;
    });

    tearDown(() => controller.dispose());

    test('vertical arrows move by whole rows', () {
      controller.select(0);
      controller.moveDown();
      expect(controller.selectedIndex, 3);
      controller.moveDown();
      expect(controller.selectedIndex, 6);
      controller.moveUp();
      expect(controller.selectedIndex, 3);
    });

    test('ArrowDown from the last row fires the boundary, not a move', () {
      controller.select(6);
      controller.moveDown();
      expect(controller.selectedIndex, 6);
      expect(boundaryCalls, 1);
    });

    test('ArrowDown above a shorter last row lands on the last item', () {
      controller.select(5);
      controller.moveDown();
      expect(controller.selectedIndex, 7);
      expect(boundaryCalls, 0);
    });

    test('horizontal arrows step through the flattened order', () {
      controller.select(2);
      controller.moveRight();
      expect(
        controller.selectedIndex,
        3,
        reason: 'right wraps to the next row',
      );
      controller.moveLeft();
      expect(controller.selectedIndex, 2);
    });

    test('ArrowRight at the very last item fires the boundary', () {
      controller.select(7);
      controller.moveRight();
      expect(controller.selectedIndex, 7);
      expect(boundaryCalls, 1);
    });

    test('ArrowUp in the first row stays put', () {
      controller.select(1);
      controller.moveUp();
      expect(controller.selectedIndex, 1);
      expect(boundaryCalls, 0);
    });
  });

  group('delegated selection', () {
    test('every read asks outside, every move writes outside', () {
      var external = -1;
      final writes = <int>[];
      final controller = ItemNavigationController(
        readIndex: () => external,
        writeIndex: (index) {
          writes.add(index);
          external = index;
        },
      );
      addTearDown(controller.dispose);
      controller.itemCount = 4;

      controller.moveDown();
      expect(writes, [0]);
      expect(controller.selectedIndex, 0);

      controller.moveDown();
      expect(writes, [0, 1]);

      // Selection changed by its outside owner: the controller follows
      // without having been told.
      external = 3;
      expect(controller.selectedIndex, 3);
      controller.moveUp();
      expect(writes, [0, 1, 2]);
      expect(external, 2);
    });

    test('the trailing boundary fires instead of writing past the end', () {
      var external = 3;
      final writes = <int>[];
      var boundaryCalls = 0;
      final controller = ItemNavigationController(
        readIndex: () => external,
        writeIndex: writes.add,
        onTrailingBoundary: () => boundaryCalls++,
      );
      addTearDown(controller.dispose);
      controller.itemCount = 4;

      controller.moveDown();
      expect(writes, isEmpty);
      expect(boundaryCalls, 1);
    });

    test('readIndex and writeIndex must come together', () {
      expect(
        () => ItemNavigationController(readIndex: () => 0),
        throwsAssertionError,
      );
      expect(
        () => ItemNavigationController(writeIndex: (_) {}),
        throwsAssertionError,
      );
    });
  });
}

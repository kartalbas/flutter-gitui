import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The root of a surface that is organised into focus regions.
///
/// Provides three things the regions need exactly once:
///
/// 1. **The ordered traversal root.** An [OrderedTraversalPolicy] group under
///    which every [BaseFocusRegion] declares its place with a numeric order,
///    so one Tab cycle walks the regions in their declared order regardless
///    of build order.
/// 2. **F6 / Shift+F6 pane cycling** — the established Windows key for moving
///    between panes (Ctrl+Tab reads as tab switching and is not used). F6
///    moves focus into the next region that has anything focusable, at that
///    region's first control in reading order; Shift+F6 cycles backwards. A
///    region with nothing to focus (a hidden panel) is skipped. F6 is a
///    function key, so a focused text field never owns it and the cycle works
///    from anywhere.
/// 3. **The focus of last resort.** A skip-traversal node wrapping the whole
///    surface that claims focus only when, two frames after mounting, nothing
///    inside has taken it. Claiming eagerly (`autofocus: true` on an
///    ancestor) is the bug this replaces: an ancestor registers its autofocus
///    before any descendant, so such an anchor always won the race and a
///    screen's own claim was silently discarded — the same defect the
///    keyboard host of `BaseDialog` fixed for dialogs, one level up. Key
///    events from whatever ends up focused still bubble through this node, so
///    an app-level [CallbackShortcuts] above the host keeps firing no matter
///    which claim won, and the node is never a Tab stop.
///
/// Deliberately built on [FocusTraversalGroup]s, not [FocusScope]s: a scope
/// would confine Tab to whichever region holds focus, while the regions are
/// meant to be stops on one shared Tab cycle.
///
/// Hosts nest: a split-view screen declares its own host (search → list →
/// details → action bar) inside the shell's content region. A nested host
/// detects its ancestor and steps back to ordering only — its regions still
/// register with it, keeping them out of the shell's F6 cycle, but F6 itself
/// bubbles on so panes always means the outermost host's panes, and the
/// focus-of-last-resort claim stays with the outermost host alone.
class BaseFocusRegionHost extends StatefulWidget {
  const BaseFocusRegionHost({super.key, this.debugLabel, required this.child});

  /// Label for the anchor node in the focus tree, for debugging and tests.
  final String? debugLabel;

  /// The surface containing the [BaseFocusRegion]s.
  final Widget child;

  @override
  State<BaseFocusRegionHost> createState() => _BaseFocusRegionHostState();
}

class _BaseFocusRegionHostState extends State<BaseFocusRegionHost> {
  late final FocusNode _anchor = FocusNode(
    debugLabel: widget.debugLabel ?? 'BaseFocusRegionHost',
    skipTraversal: true,
  );
  final OrderedTraversalPolicy _policy = OrderedTraversalPolicy();
  final List<BaseFocusRegionState> _regions = <BaseFocusRegionState>[];

  /// Whether this host sits inside another host. A nested host orders its
  /// regions but neither handles F6 (pane cycling belongs to the outermost
  /// host) nor claims the focus of last resort (there can be only one).
  bool _nested = false;
  bool _claimScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nested = _BaseFocusRegionHostScope.maybeOf(context) != null;
    if (_nested || _claimScheduled) return;
    _claimScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pending autofocus requests (a screen's, possibly registered as late
      // as the first layout pass) are applied in a microtask after this
      // frame's callbacks; decide on the next frame, after they ran, and make
      // sure that frame actually comes.
      WidgetsBinding.instance.scheduleFrame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (FocusScope.of(context).focusedChild == null) {
          _anchor.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _anchor.dispose();
    super.dispose();
  }

  void _register(BaseFocusRegionState region) {
    _regions.add(region);
  }

  void _unregister(BaseFocusRegionState region) {
    _regions.remove(region);
  }

  /// Moves focus into the next (or previous) region that has anything
  /// focusable. Returns false when no region does, so the key can bubble on.
  bool _cycle({required bool backward}) {
    final regions = List<BaseFocusRegionState>.of(_regions)
      ..sort((a, b) => a.widget.order.compareTo(b.widget.order));
    if (regions.isEmpty) return false;

    final primary = FocusManager.instance.primaryFocus;
    var index = primary == null
        ? -1
        : regions.indexWhere((region) => region._containsFocus(primary));
    if (index < 0) {
      // Focus sits outside every region (on the anchor): F6 enters the first
      // region and Shift+F6 the last, as if the cycle had just wrapped.
      index = backward ? 0 : regions.length - 1;
    }

    final step = backward ? -1 : 1;
    for (var offset = 1; offset <= regions.length; offset++) {
      var target = (index + step * offset) % regions.length;
      if (target < 0) target += regions.length;
      if (regions[target].focusFirstChild()) return true;
    }
    return false;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // A nested host lets F6 bubble to the outermost host: pane cycling is
    // one gesture over the whole surface, not one per nesting level.
    if (_nested) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.f6) {
      return KeyEventResult.ignored;
    }
    final backward = HardwareKeyboard.instance.isShiftPressed;
    return _cycle(backward: backward)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: _policy,
      child: Focus(
        focusNode: _anchor,
        skipTraversal: true,
        onKeyEvent: _onKeyEvent,
        child: _BaseFocusRegionHostScope(host: this, child: widget.child),
      ),
    );
  }
}

/// Lets regions find their host — and a nested host find its ancestor —
/// without threading a reference through every intermediate widget.
class _BaseFocusRegionHostScope extends InheritedWidget {
  const _BaseFocusRegionHostScope({required this.host, required super.child});

  final _BaseFocusRegionHostState host;

  static _BaseFocusRegionHostState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_BaseFocusRegionHostScope>()
      ?.host;

  @override
  bool updateShouldNotify(_BaseFocusRegionHostScope oldWidget) =>
      host != oldWidget.host;
}

/// One region of a [BaseFocusRegionHost] surface: a pane that Tab visits at
/// its declared [order] and F6 jumps to as a unit.
///
/// Internally a [FocusTraversalOrder] wrapping a [FocusTraversalGroup] with a
/// [ReadingOrderTraversalPolicy], so controls inside the region are walked in
/// reading order while the regions themselves follow their numeric order
/// under the host. The region adds no focus node to the Tab order and does
/// not change what the user sees; a region whose content has nothing
/// focusable is simply skipped by both Tab and F6.
class BaseFocusRegion extends StatefulWidget {
  const BaseFocusRegion({
    super.key,
    required this.order,
    this.debugLabel,
    required this.child,
  });

  /// The region's place in the surface's Tab and F6 cycle. Regions are
  /// visited in ascending order.
  final double order;

  /// Label for the region's marker node in the focus tree, for debugging and
  /// tests.
  final String? debugLabel;

  /// The pane this region wraps.
  final Widget child;

  @override
  State<BaseFocusRegion> createState() => BaseFocusRegionState();
}

/// Public so a screen holding a `GlobalKey<BaseFocusRegionState>` can hand
/// focus to a region programmatically — history's Enter on a commit row moves
/// focus into the details region through [focusFirstChild].
class BaseFocusRegionState extends State<BaseFocusRegion> {
  /// Marks the region's subtree in the focus tree so the host can tell which
  /// region holds focus and hand focus to a region's first control. Never
  /// focusable and never a Tab stop itself.
  late final FocusNode _marker = FocusNode(
    debugLabel: widget.debugLabel ?? 'BaseFocusRegion(${widget.order})',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final ReadingOrderTraversalPolicy _policy = ReadingOrderTraversalPolicy();
  _BaseFocusRegionHostState? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = _BaseFocusRegionHostScope.maybeOf(context);
    if (host != _host) {
      _host?._unregister(this);
      _host = host;
      _host?._register(this);
    }
  }

  @override
  void didUpdateWidget(BaseFocusRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _marker.debugLabel =
        widget.debugLabel ?? 'BaseFocusRegion(${widget.order})';
  }

  @override
  void dispose() {
    _host?._unregister(this);
    _marker.dispose();
    super.dispose();
  }

  bool _containsFocus(FocusNode node) =>
      node == _marker || node.ancestors.contains(_marker);

  /// Focuses the region's first control in reading order — the same order Tab
  /// uses inside the region. Returns false when nothing here can take focus.
  bool focusFirstChild() {
    final candidates = _marker.traversalDescendants.toList();
    if (candidates.isEmpty) return false;
    _policy.sortDescendants(candidates, candidates.first).first.requestFocus();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order),
      child: Focus(
        focusNode: _marker,
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        child: FocusTraversalGroup(policy: _policy, child: widget.child),
      ),
    );
  }
}

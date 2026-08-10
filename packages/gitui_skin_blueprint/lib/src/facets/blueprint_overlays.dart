import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../blueprint_ink.dart';

/// Things that appear on top, naked.
///
/// One rule runs through all four members: **whatever crosses into a route or
/// an overlay entry is re-established before it renders.** A route is built by
/// a navigator that sits above the place it was opened from, so nothing
/// inherited at the call site is there when the route builds - that is the
/// measured macOS failure, where a theme that is not an `InheritedTheme`
/// silently fails to arrive and a dark application opens a light dialog. The
/// blueprint has no brightness to get wrong, and it re-establishes anyway,
/// because it is the template the next skin copies: a blueprint that skipped
/// the seam because it happened to survive skipping it would teach the one
/// skin that cannot survive it to skip it too.
///
/// Concretely: all four members render a host, and a host's `build` re-installs
/// the scope and the root treatment and cannot be bypassed. Nothing here
/// rebuilds that wrapper by hand any more, and that is the point - the two
/// members whose content is the skin's own (a menu's rows, a notice's strip)
/// reach their payload only from inside `build`, so a skin that forgot the
/// host gets an EMPTY overlay rather than a silently unthemed one. The skin's
/// own arrangement around the content - the positioning, the surface, the
/// dismiss action - goes in as the host's `frame` or as the body it builds, so
/// it lands inside the skin-painted fence where it belongs.
///
/// The naked route itself is `showGeneralDialog`, which is exported from
/// `package:flutter/widgets.dart` - a real modal route, a real barrier and a
/// real focus scope, with no design language anywhere. Every transition is
/// `Duration.zero` and every barrier is transparent, because a scrim would be
/// a colour the application never asked for.
final class BlueprintOverlays implements SkinOverlays {
  /// Takes the distance every rung resolves against.
  const BlueprintOverlays(this.distance);

  /// How far apart things are under this instrument. Zero unless the skin was
  /// built with a distance.
  final BlueprintDistance distance;

  /// Pushes the dialog's own naked route and renders the host as its content.
  ///
  /// The host is the whole content: between this route and the surface sit
  /// the application's keyboard contract and the skin's `chrome.dialogSurface`,
  /// both already composed into [host] by the API package, so Escape, Enter
  /// and the surface's arrangement are honoured without this member knowing
  /// about any of them. [DialogSpec.barrierDismissible] is consumed here -
  /// whether clicking outside completes the dialog is the route's question -
  /// and the title doubles as the barrier's accessible name.
  @override
  Future<T?> presentDialog<T>(
    BuildContext context,
    DialogSpec spec,
    SkinContentHost host,
  ) => showGeneralDialog<T>(
    context: context,
    barrierDismissible: spec.barrierDismissible,
    barrierLabel: spec.title,
    barrierColor: const Color(0x00000000),
    transitionDuration: Duration.zero,
    pageBuilder:
        (
          BuildContext routeContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => host.build(routeContext),
  );

  /// Offers the entries at the asked-for point and reports the chosen index.
  ///
  /// The menu's rows are the SKIN's content, so the host hands them over
  /// inside its own `build` rather than as a parameter: everything this member
  /// draws is drawn under the re-established scope, and there is no version of
  /// this code that renders a menu without one. The chosen entry is dispatched
  /// where its row is built - a [MenuAction]'s `onPressed` is invoked, a
  /// [MenuCheckable]'s `onChanged` receives its flipped value - so no call site
  /// has to switch over the index it gets back.
  ///
  /// Keyboard: the first choosable entry autofocuses, the platform's default
  /// bindings move focus with the arrows and activate with Enter or Space,
  /// and Escape resolves the route's own [DismissIntent] mapping to close the
  /// menu with nothing chosen.
  @override
  Future<int?> presentMenu(
    BuildContext context, {
    required Offset at,
    required SkinMenuHost host,
  }) => showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    // The barrier's accessible name. A literal rather than a translation
    // because a skin package owns no translations; the instrument speaks
    // marker language everywhere, including to a screen reader.
    barrierLabel: '[dismiss]',
    barrierColor: const Color(0x00000000),
    transitionDuration: Duration.zero,
    pageBuilder:
        (
          BuildContext routeContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => host.build(
          routeContext,
          (BuildContext inner, List<MenuEntry> entries) => _Dismissible(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: at.dx,
                  top: at.dy,
                  child: _BlueprintMenuSurface(entries: entries),
                ),
              ],
            ),
          ),
        ),
  );

  /// Builds the control that offers the host's choices, anchored to itself.
  ///
  /// The naked trigger: an outlined pressable carrying the anchor's facts as
  /// marks - the icon's role, the tone, `[*]` while the subject is engaged,
  /// `[disabled]` while it may not be opened - sized by the scale's rung. The
  /// menu opens under the trigger's leading corner, which is the same corner
  /// this facet's popover uses, so the instrument has ONE answer to "where
  /// does an anchored surface go".
  @override
  Widget menuAnchor(
    BuildContext context,
    MenuAnchorSpec spec,
    SkinMenuHost host,
  ) => Builder(
    builder: (BuildContext anchorContext) {
      final String toneMark = BlueprintMarks.tone(spec.tone);
      return BlueprintPressable(
        onPressed: spec.enabled
            ? () {
                Offset at = Offset.zero;
                final RenderObject? renderObject = anchorContext
                    .findRenderObject();
                if (renderObject is RenderBox && renderObject.hasSize) {
                  at = renderObject.localToGlobal(
                    Offset(0, renderObject.size.height),
                  );
                }
                presentMenu(anchorContext, at: at, host: host);
              }
            : null,
        semanticsLabel: spec.tooltip,
        tooltip: spec.tooltip,
        selected: spec.selected ? true : null,
        child: BlueprintBox(
          minExtent: BlueprintGeometry.extent(anchorContext, spec.scale),
          filled: spec.selected,
          // A Wrap and not a Row, for the reason every blueprint control
          // lays its marks out this way: the instrument draws a mark as
          // WORDS, and words handed a narrow budget (the overflow bar's
          // 48 px anchor share) wrap instead of overflowing.
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              BlueprintMark(BlueprintMarks.icon(spec.icon)),
              if (toneMark != BlueprintMarks.none) BlueprintMark(toneMark),
              // The count rides on the trigger, as a mark like every other
              // fact: the same `(n)` the rail's destinations and the toolbar's
              // actions already draw for the same word.
              if (spec.badgeCount != null)
                BlueprintMark(BlueprintMarks.count(spec.badgeCount!)),
              if (!spec.enabled) const BlueprintMark(BlueprintMarks.disabled),
            ],
          ),
        ),
      );
    },
  );

  /// Attaches the host's content to the control the user just operated.
  ///
  /// The anchor is the given context's own render box - the control the
  /// gesture happened in - and the popover opens under its leading corner.
  /// [PopoverSpec.continuesAnchor] is honoured as a width match: a suggestion
  /// list that continues a field takes the field's measured width, which is
  /// the one fact about the relationship the application stated.
  @override
  Future<T?> presentPopover<T>(
    BuildContext context,
    PopoverSpec spec,
    SkinContentHost host,
  ) {
    Offset? at;
    double? anchorWidth;
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      at = renderObject.localToGlobal(Offset(0, renderObject.size.height));
      anchorWidth = renderObject.size.width;
    }
    final bool matchAnchor = spec.continuesAnchor && anchorWidth != null;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: spec.barrierDismissible,
      barrierLabel: spec.semanticsLabel,
      barrierColor: const Color(0x00000000),
      transitionDuration: Duration.zero,
      pageBuilder:
          (
            BuildContext routeContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) => host.build(
            routeContext,
            // The frame is everything the SKIN puts around the application's
            // content: the anchoring, the box, the paper and the dismiss
            // action. It is applied inside the host's own fence, so none of it
            // is attributed to the application, and the content resumes at its
            // own boundary inside it.
            frame: (BuildContext inner, Widget content) {
              final Widget surface = Semantics(
                container: true,
                label: spec.semanticsLabel,
                child: BlueprintBox(
                  rings: BlueprintGeometry.rings(Elevation.overlay),
                  child: ColoredBox(
                    // `inner` and not the anchor's context: the vocabulary is
                    // installed by the root treatment the host re-established
                    // INSIDE this route, and reading it from the call site
                    // would quietly resolve the resting instrument while a
                    // chaos family was running.
                    color: BlueprintInk.paper(inner),
                    child: matchAnchor
                        ? SizedBox(width: anchorWidth, child: content)
                        : content,
                  ),
                ),
              );
              return _Dismissible(
                child: Stack(
                  children: <Widget>[
                    if (at == null)
                      Center(child: surface)
                    else
                      Positioned(left: at.dx, top: at.dy, child: surface),
                  ],
                ),
              );
            },
          ),
    );
  }

  /// Says something happened, without taking the application away.
  ///
  /// The notice is an overlay entry at the top of the root overlay, wrapped
  /// in the envelope's own scope and root treatment because the overlay sits
  /// above wherever the root treatment was installed - the same seam as a
  /// route, crossed the same way. A brief notice dismisses itself after the
  /// frame that painted it, which is `Duration.zero + 1 frame`: the only
  /// lifetime shorter than every design language's and longer than nothing.
  /// A persistent notice stays until the application uses the handle, which
  /// is the behaviour the handle exists to keep.
  @override
  NoticeHandle notify(BuildContext context, SkinNoticeHost host) {
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext overlayContext) => host.build(
        overlayContext,
        (BuildContext inner, NoticeSpec spec) => Align(
          alignment: Alignment.topCenter,
          child: _BlueprintNoticeSurface(spec: spec),
        ),
      ),
    );
    final _BlueprintNoticeHandle handle = _BlueprintNoticeHandle(entry);
    overlay.insert(entry);
    // The lifetime is read off the host rather than out of the spec, because
    // arming the dismissal has to happen before anything is built and the
    // notice's words are deliberately not reachable out here.
    if (host.lifetime == NoticeLifetime.brief) {
      WidgetsBinding.instance.addPostFrameCallback(
        (Duration _) => handle.dismiss(),
      );
    }
    return handle;
  }
}

/// Closes its route with nothing chosen when the user asks to leave.
///
/// The platform's default shortcut map already turns Escape into a
/// [DismissIntent]; this widget is the action that answers it, placed above
/// the overlay's focused content so the intent resolves here rather than
/// falling through to whatever is beneath the barrier.
class _Dismissible extends StatelessWidget {
  const _Dismissible({required this.child});

  /// The overlay content being guarded.
  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      DismissIntent: CallbackAction<DismissIntent>(
        onInvoke: (DismissIntent _) {
          Navigator.of(context).pop();
          return null;
        },
      ),
    },
    child: child,
  );
}

/// The naked menu: a column of outlined rows on paper.
class _BlueprintMenuSurface extends StatelessWidget {
  const _BlueprintMenuSurface({required this.entries});

  /// The entries, in the application's order.
  final List<MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    bool autofocusGiven = false;
    final List<Widget> rows = <Widget>[];
    for (int index = 0; index < entries.length; index++) {
      switch (entries[index]) {
        case MenuSeparator():
          rows.add(
            Container(
              height: BlueprintInk.hairline(context),
              color: BlueprintInk.ink(context),
            ),
          );
        case final MenuSection section:
          rows.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BlueprintMark(BlueprintMarks.textRole(TextRole.sectionTitle)),
                BlueprintText(section.label),
              ],
            ),
          );
        case final MenuAction action:
          final bool enabled = action.isEnabled;
          final bool autofocus = enabled && !autofocusGiven;
          autofocusGiven = autofocusGiven || autofocus;
          rows.add(
            _row(
              context,
              index: index,
              enabled: enabled,
              autofocus: autofocus,
              checked: null,
              // The longer explanation - a disabled entry's reason - is
              // announced rather than hovered, the same recorded answer
              // BlueprintPressable gives every tooltip: a hovering surface
              // is a design, and this instrument has none.
              tooltip: action.tooltip,
              dispatch: () => action.onPressed!(),
              children: <Widget>[
                // A markless entry renders its words alone: the instrument
                // reserves nothing for a mark that was never stated.
                if (action.icon != null)
                  BlueprintMark(BlueprintMarks.icon(action.icon!)),
                BlueprintText(action.label),
                if (action.role == MenuActionRole.destructive)
                  BlueprintMark(BlueprintMarks.tone(Tone.danger)),
              ],
            ),
          );
        case final MenuCheckable checkable:
          final bool enabled = checkable.isEnabled;
          final bool autofocus = enabled && !autofocusGiven;
          autofocusGiven = autofocusGiven || autofocus;
          rows.add(
            _row(
              context,
              index: index,
              enabled: enabled,
              autofocus: autofocus,
              checked: checkable.checked,
              dispatch: () => checkable.onChanged!(!checkable.checked),
              children: <Widget>[
                BlueprintMark(BlueprintMarks.check(checkable.checked)),
                if (checkable.icon != null)
                  BlueprintMark(BlueprintMarks.icon(checkable.icon!)),
                BlueprintText(checkable.label),
              ],
            ),
          );
        case final MenuChoice choice:
          final bool enabled = choice.isEnabled;
          final bool autofocus = enabled && !autofocusGiven;
          autofocusGiven = autofocusGiven || autofocus;
          rows.add(
            _row(
              context,
              index: index,
              enabled: enabled,
              autofocus: autofocus,
              // One-of-N, so the row reports "chosen", not "checked": the
              // pressable announces selection state, which is the naked
              // radio.
              checked: null,
              selected: choice.selected,
              dispatch: () => choice.onSelect!(),
              children: <Widget>[
                BlueprintMark(BlueprintMarks.selected(choice.selected)),
                if (choice.icon != null)
                  BlueprintMark(BlueprintMarks.icon(choice.icon!)),
                BlueprintText(choice.label),
              ],
            ),
          );
      }
    }
    return BlueprintBox(
      rings: BlueprintGeometry.rings(Elevation.overlay),
      child: ColoredBox(
        color: BlueprintInk.paper(context),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    );
  }

  /// One choosable row. Choosing pops the route with the row's index in the
  /// ORIGINAL entry list - which is the position the caller hears back - and
  /// then runs the entry.
  ///
  /// In that order, and it matters: an entry's callback routinely opens
  /// another overlay, and popping first means it does so against a navigator
  /// this menu has already left. The dispatch happens here rather than after
  /// the route's future because the entries are the host's and are reachable
  /// only where the rows are built, which is the same place the row knows
  /// which entry it is.
  Widget _row(
    BuildContext context, {
    required int index,
    required bool enabled,
    required bool autofocus,
    required bool? checked,
    required VoidCallback dispatch,
    required List<Widget> children,
    bool? selected,
    String? tooltip,
  }) => BlueprintPressable(
    onPressed: enabled
        ? () {
            Navigator.of(context).pop(index);
            dispatch();
          }
        : null,
    autofocus: autofocus,
    isButton: checked == null && selected == null,
    checked: checked,
    selected: selected,
    tooltip: tooltip,
    child: BlueprintBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ...children,
          if (!enabled) const BlueprintMark(BlueprintMarks.disabled),
        ],
      ),
    ),
  );
}

/// The naked notice: marks, words and actions in one outlined strip.
class _BlueprintNoticeSurface extends StatelessWidget {
  const _BlueprintNoticeSurface({required this.spec});

  /// What the notice says and offers.
  final NoticeSpec spec;

  @override
  Widget build(BuildContext context) {
    final String marks =
        '${BlueprintMarks.tone(spec.tone)}'
        '${spec.icon == null ? BlueprintMarks.none : BlueprintMarks.icon(spec.icon!)}';
    return BlueprintBox(
      rings: BlueprintGeometry.rings(Elevation.overlay),
      child: ColoredBox(
        color: BlueprintInk.paper(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (marks.isNotEmpty) BlueprintMark(marks),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  BlueprintText(spec.title),
                  if (spec.body != null) BlueprintText(spec.body!),
                ],
              ),
            ),
            for (final NoticeAction action in spec.actions)
              BlueprintPressable(
                onPressed: action.onPressed,
                tooltip: action.tooltip,
                child: BlueprintBox(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (action.icon != null)
                        BlueprintMark(BlueprintMarks.icon(action.icon!)),
                      BlueprintText(action.label),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The two things a live notice can do, and nothing else.
final class _BlueprintNoticeHandle implements NoticeHandle {
  _BlueprintNoticeHandle(this._entry);

  OverlayEntry? _entry;

  @override
  void dismiss() {
    final OverlayEntry? entry = _entry;
    _entry = null;
    if (entry == null) return;
    if (entry.mounted) entry.remove();
    // Disposal is deferred a frame because remove() itself defers the
    // removal to the end of the frame when it is called mid-build, and an
    // entry may not be disposed while an overlay still holds it.
    WidgetsBinding.instance.addPostFrameCallback(
      (Duration _) => entry.dispose(),
    );
  }

  @override
  bool get isShowing => _entry != null;
}

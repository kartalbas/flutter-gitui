import 'package:flutter/widgets.dart';

import '../content_port.dart';
import '../specs/chrome_specs.dart';
import '../specs/overlay_specs.dart';

/// Things that appear on top.
///
/// Five members, and one rule that runs through all of them: **the application
/// owns the entry point, this package owns the wrapper, the skin owns the
/// route.** A skin never gets to define how an overlay is opened, so it never
/// gets to skip the wrapper - which is what turns a measured, shippable,
/// silent bug into something that cannot be written.
///
/// The bug is real and was measured rather than imagined. Fluent's dialogs
/// capture inherited themes but its flyouts do not, and macOS's theme is a
/// plain `InheritedWidget` rather than an `InheritedTheme`, so it cannot be
/// carried into a route the way Fluent's can. A contract that is right only
/// half the time is a contract that will be got wrong.
///
/// **All five members take a host, and none takes a bare envelope.** The two
/// whose content is the skin's own - a menu's rows, a notice's strip - used to
/// be handed the envelope and left to rebuild the wrapper themselves, which
/// meant the guarantee held for half the facet and the other half ran on the
/// rule somebody remembers. Their payloads are now reachable only from inside
/// their host's `build`, so forgetting the host produces an empty overlay in
/// all four cases: loud, and identical in shape.
abstract interface class SkinOverlays {
  /// **Take the application away until the user answers this.**
  ///
  /// The skin pushes ITS OWN route with ITS OWN language's helper and MUST
  /// render [host] as the content. The route is not a contract type on
  /// purpose: forcing a `PageRoute` subclass would make macOS's own alert
  /// helper unreachable and oblige that skin to re-derive the barrier by hand,
  /// which is route-level hand-painting imposed at exactly the point the
  /// contract exists to prevent it.
  ///
  /// A skin that forgets [host] does not get a wrongly themed dialog - it gets
  /// an EMPTY one, which is a loud failure rather than a silent one.
  ///
  /// **[route] is deliberately NOT the whole dialog.** It carries only what a
  /// route can honestly know: the name the barrier answers to, what kind of
  /// thing is inside, and whether clicking outside completes it - the three
  /// facts that cannot change while the dialog is open. Everything the surface
  /// shows is a view of application state, rebuilt every frame inside the
  /// route, and a skin never sees it: `chrome.dialogSurface` does, from within
  /// [host]. That split is what lets `Overlays.dialogFrom` exist at all - a
  /// dialog whose affirmative action turns on once a field validates has to be
  /// routed BEFORE the state deciding its frame exists, and demanding a whole
  /// `DialogSpec` here would have made every such call site invent one.
  Future<T?> presentDialog<T>(
    BuildContext context,
    DialogRouteSpec route,
    SkinContentHost host,
  );

  /// **Offer these choices at this point on the screen.**
  ///
  /// Returns the index of the entry the user chose, or null if they chose
  /// none. An index rather than a callback per entry, so the skin dispatches
  /// by position and no call site has to invent keys - and because the entries
  /// live inside [host], that dispatch happens where the rows are built,
  /// which is the only place both the entry and the row exist at once.
  Future<int?> presentMenu(
    BuildContext context, {
    required Offset at,
    required SkinMenuHost host,
  });

  /// **Build the control that offers these choices, anchored to itself.**
  ///
  /// The widget-returning member of an overlay facet, because an anchored
  /// menu is one thing with two halves and the seam between them is exactly
  /// what every language answers differently: Material opens below its own
  /// ink-bearing icon button, Fluent attaches a flyout with its own placement
  /// resolution, macOS's pull-down opens OVER the control. [presentMenu]
  /// stating a bare point forced the application to perform that geometry
  /// itself at every trigger; this member takes the trigger and the geometry
  /// into the skin together, which is where both have always belonged.
  ///
  /// The entries stay inside [host] for the same reason they do on
  /// [presentMenu]: they are reachable only where the menu's rows are built,
  /// so the skin that opens the menu re-establishes the scope by
  /// construction.
  Widget menuAnchor(
    BuildContext context,
    MenuAnchorSpec spec,
    SkinMenuHost host,
  );

  /// **Attach this content to the control the user just operated.**
  Future<T?> presentPopover<T>(
    BuildContext context,
    PopoverSpec spec,
    SkinContentHost host,
  );

  /// **Tell the user this happened, without taking the application away.**
  ///
  /// Returns a handle rather than nothing, because the application already
  /// dismisses and replaces its own notices today - a `void` return would have
  /// been a regression against shipped behaviour. macOS has no toast idiom of
  /// any kind, so that skin renders the notice in the shell's status area: a
  /// registered deviation, not a hand-painted lookalike.
  ///
  /// `host.lifetime` is readable without building anything, because a skin has
  /// to arm its own dismissal before it renders; everything the notice SAYS is
  /// inside `host.build`.
  NoticeHandle notify(BuildContext context, SkinNoticeHost host);
}

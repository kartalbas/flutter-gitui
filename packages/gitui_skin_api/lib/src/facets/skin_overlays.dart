import 'package:flutter/widgets.dart';

import '../content_port.dart';
import '../specs/chrome_specs.dart';
import '../specs/overlay_specs.dart';

/// Things that appear on top.
///
/// Four members, and one rule that runs through all of them: **the application
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
/// **All four members take a host, and none takes a bare envelope.** The two
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
  Future<T?> presentDialog<T>(
    BuildContext context,
    DialogSpec spec,
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

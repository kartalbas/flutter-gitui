import 'package:flutter/widgets.dart';

import '../specs/chrome_specs.dart';

/// The frame: the root, the shell, the screens and the dialog surface.
///
/// Four members. Everything a censusing eye proposed as a fifth - the screen's
/// primary action, the selection bar, the shell's activity line, the shell's
/// blocking progress - is a SLOT on one of these specs instead, because a
/// member would have let a screen mount those things wherever it liked, and
/// placement is precisely where the three languages diverge.
abstract interface class SkinChrome {
  /// **What does this design language need installed above everything?**
  ///
  /// The single `WidgetsApp` root stays exactly where it is; this wraps
  /// beneath it. A skin installs its own inherited theme here - and its own
  /// default text style and icon treatment - which is why `ThemeData` never
  /// crosses the contract at all. It is also the reason the blueprint is an
  /// instrument rather than a backdrop: it installs INK defaults, so an
  /// unstyled SDK fallback renders illegally instead of invisibly.
  ///
  /// **[child] is the contract's one `Widget`-typed parameter, and the
  /// exemption is reasoned rather than left over.** Everywhere else a widget
  /// crossing into a skin is application content and travels as a
  /// [ContentPort], so the attribution walk resumes at it; `no_widget_in_contract`
  /// enforces that and names this member as its single exception. Here the
  /// argument is never supplied by application code: `SkinScope.install` and
  /// the overlay hosts compose it, and they have already planted the fence
  /// OUTSIDE this call and the boundary INSIDE it, at the exact point the
  /// application's own content resumes. Typing it as a port instead would put
  /// the resume above the skin's own overlay frame and mis-attribute every
  /// skin-built popover, menu and notice surface to the application - the
  /// same defect this parameter's arrangement exists to remove, pointing the
  /// other way.
  ///
  /// So a skin implementing this wraps [child] and never mounts, fences or
  /// re-ports it.
  Widget wrapRoot(
    BuildContext context, {
    required Widget child,
    required SkinRequest request,
  });

  /// **What does the whole application window look like?**
  ///
  /// Everything about the window that is not one screen's content:
  /// where the destinations live, where the actions live, where a standing
  /// message goes, where a running operation is reported. The application
  /// hands over the facts and the skin decides the arrangement - a rail beside
  /// the content, a navigation pane, a sidebar and a unified toolbar.
  Widget shell(BuildContext context, ShellSpec spec);

  /// **What does one screen inside the shell look like?**
  ///
  /// The successor to the 18 raw scaffolds and the shared app bar: a screen
  /// states its title, its body, its own actions and whatever it is currently
  /// warning about, and never how any of that is framed.
  ///
  /// **A screen is wired LAST, and that is a property of this member, not of
  /// any one migration.** No skin promises to host another design language's
  /// raw widgets: the naked skin's screen deliberately provides no `Material`
  /// ancestor - providing one would be Material leaking under a neutral name,
  /// the substitution failure §10 of `docs/SKIN-CONTRACT-MEMBERS.md` exists
  /// to catch - so a body that still contains widgets which assume one (a raw
  /// `TextFormField`, an `ActionChip`, an `InkWell`) pins its screen to the
  /// hand-built scaffold until those widgets answer the contract themselves.
  /// The blueprint half of the scene sweep is the gate that enforces this;
  /// this sentence is the statement of it.
  Widget screen(BuildContext context, ScreenSpec spec);

  /// **What does the inside of a dialog look like?**
  ///
  /// Only the SURFACE - the title, the content and the actions. The ROUTE that
  /// carries it belongs to `SkinOverlays.presentDialog`, because a contract
  /// that owned the route class would make `showMacosAlertDialog` unreachable
  /// and force the macOS skin to re-derive its own barrier by hand. Between
  /// the two sits the application's keyboard host, which is why the split is
  /// three layers and not two.
  Widget dialogSurface(BuildContext context, DialogSpec spec);
}

import 'package:flutter/widgets.dart';

import '../content_port.dart';
import '../icon_role.dart';
import '../vocabulary.dart';
import 'surface_specs.dart';
import 'toolbar_specs.dart';

/// Everything a skin needs in order to resolve a look, gathered from the
/// user's own configuration.
///
/// Carried as data so that the SKIN consumes it and the application never
/// does. This is what deletes `AnimationSpeedExtension` and
/// `context.quickAnimation` as application-readable values: the application
/// states what the user chose, and only the skin turns that into a duration, a
/// palette or a font.
@immutable
final class SkinRequest {
  /// Gathers the user's choices for the skin to resolve.
  const SkinRequest({
    required this.brightness,
    required this.accentSeed,
    required this.textScale,
    required this.animationScale,
    required this.monoFamily,
    required this.uiFamily,
  });

  /// Whether the user is working in light or in dark. `Brightness` is a
  /// `dart:ui` type with no design language attached to it.
  final Brightness brightness;

  /// The seed the user picked for the application's own colour, as an opaque
  /// integer. Not a `Color`: what a skin derives from a seed - one hue, a
  /// tonal palette, a system accent it prefers instead - is the skin's answer.
  final int accentSeed;

  /// The user's text-size preference, as a multiplier of the skin's own ramp.
  final double textScale;

  /// The user's motion preference, as a multiplier of the skin's own
  /// durations. Zero means "no motion", which the skin honours by resolving
  /// every [MotionRole] to nothing.
  final double animationScale;

  /// The monospace family the user chose for code, diffs and hashes. A family
  /// NAME rather than a `TextStyle`: which size, weight and line height it is
  /// rendered at stays the skin's answer.
  final String monoFamily;

  /// The interface family the user chose for everything else.
  final String uiFamily;

  @override
  bool operator ==(Object other) =>
      other is SkinRequest &&
      other.brightness == brightness &&
      other.accentSeed == accentSeed &&
      other.textScale == textScale &&
      other.animationScale == animationScale &&
      other.monoFamily == monoFamily &&
      other.uiFamily == uiFamily;

  @override
  int get hashCode => Object.hash(
    brightness,
    accentSeed,
    textScale,
    animationScale,
    monoFamily,
    uiFamily,
  );
}

/// The skin's legitimate claims on the single application root.
///
/// Three members of the whole contract do not return a `Widget` or a `Route`,
/// and they all live here. Each is justified by a Flutter plumbing
/// requirement, each has a trivial naked answer, and a lint confines every
/// read of this type to `lib/main.dart` - so application code cannot reach
/// them even though they exist.
///
/// Notably ABSENT: there is no `ThemeData` member. A skin builds its own
/// inherited theme inside `chrome.wrapRoot`, so `ThemeData` never crosses the
/// contract at all.
@immutable
final class SkinRootClaims {
  /// Declares what this skin needs installed at the application root.
  const SkinRootClaims({
    this.localizationsDelegates = const <LocalizationsDelegate<Object?>>[],
    this.scrollBehavior,
    this.windowChrome = WindowChrome.hostDefault,
  });

  /// EXCEPTION 1 - the localisation delegates this skin's package needs before
  /// it can push anything.
  ///
  /// Measured, not defensive: `fluent.showDialog` runs
  /// `debugCheckHasFluentLocalizations` BEFORE it pushes a route, and
  /// `macos_ui` calls `MaterialLocalizations.of(context)` un-guarded in seven
  /// files. The single application root installs the UNION over every
  /// registered skin, so a skin is not self-contained at the widget level - it
  /// has a legitimate claim on the root. The blueprint answers `const []`.
  final List<LocalizationsDelegate<Object?>> localizationsDelegates;

  /// EXCEPTION 2 - the scroll physics and scrollbar behaviour this skin
  /// expects.
  ///
  /// A `ScrollBehavior` is a BEHAVIOUR object, not a design value, and
  /// application code never reads it - only the root installs it. The
  /// blueprint answers `const ScrollBehavior()`.
  final ScrollBehavior? scrollBehavior;

  /// EXCEPTION 3 - what the window frame should be, as an enum rather than a
  /// value.
  ///
  /// Window chrome is a skin decision that today lives as a one-time
  /// `window_manager` call in `main.dart`, which is theming outside every
  /// skin. Fluent wants Mica and its own title bar, macOS wants traffic lights
  /// and a unified toolbar, Material wants the host default.
  final WindowChrome windowChrome;
}

/// Who this application is, in the terms a frame needs to introduce it.
///
/// Carried because macOS REQUIRES it: `MacosAlertDialog.appIcon` is a required
/// `Widget`, so a skin that cannot reach an application icon cannot call its
/// own canonical dialog at all.
@immutable
final class AppIdentity {
  /// Names the application for whichever frame is drawing it.
  const AppIdentity({
    required this.name,
    required this.icon,
    required this.appIcon,
  });

  /// The application's name, already localised where it needs to be.
  final String name;

  /// The application's mark as a role, for the frames that draw a glyph.
  final IconRole icon;

  /// The application's mark as a raster image, for the frames that require
  /// one. An `ImageProvider` is an asset reference, not a design value: it
  /// says WHICH picture, never how large or how rounded.
  final ImageProvider<Object> appIcon;
}

/// One place the user can navigate to from the shell.
@immutable
final class ShellDestination {
  /// Declares a destination and what it contains.
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.body,
    this.badgeCount,
  });

  /// The destination's name, and its accessible name.
  final String label;

  /// Its mark while it is not the current destination.
  final IconRole icon;

  /// Its mark while it is. A separate role rather than a weight flag, because
  /// "selected" is drawn with a filled variant in one language, a different
  /// glyph in another and a weight change in a third.
  final IconRole selectedIcon;

  /// How many things are waiting here, or null for "nothing to report".
  final int? badgeCount;

  /// What this destination shows.
  ///
  /// The body belongs to the DESTINATION rather than to the shell, and it is a
  /// BUILDER because that is the only shape all three frames drive without a
  /// wrapper: Fluent wants it at `PaneItem.body`, macOS builds through
  /// `ContentArea(builder:)`, and Material and macOS both read
  /// `destinations[selected].body()` trivially.
  final ContentPort Function() body;
}

/// The command-log panel: a secondary region beside the content.
@immutable
final class ShellAside {
  /// Declares the aside and whether it is showing.
  const ShellAside({
    required this.title,
    required this.content,
    required this.visible,
    this.onVisibilityChanged,
    this.actions = const <ToolbarActionEntry>[],
  });

  /// What the region is called.
  final String title;

  /// What is in it.
  final ContentPort content;

  /// Whether the user has asked to see it. A fact about application state, not
  /// a look - the skin decides whether that means a drawer, an end sidebar or
  /// a docked panel.
  final bool visible;

  /// How to tell the application the user closed or opened it. Null means the
  /// application owns that gesture elsewhere and the skin must not draw a
  /// second affordance for it.
  final ValueChanged<bool>? onVisibilityChanged;

  /// Actions belonging to the region's own header.
  final List<ToolbarActionEntry> actions;
}

/// The standing line the shell keeps about the state of things.
@immutable
final class ShellStatus {
  /// Declares what the shell should be saying right now.
  const ShellStatus({
    required this.label,
    this.detail,
    this.icon,
    this.tone = Tone.neutral,
    this.onTap,
  });

  /// The short statement: the current branch, the last sync, "offline".
  final String label;

  /// The longer form, for wherever the frame has room.
  final String? detail;

  /// A mark beside it.
  final IconRole? icon;

  /// What the statement means.
  final Tone tone;

  /// What happens if the user acts on it. Null means it is only a report.
  final VoidCallback? onTap;
}

/// A non-blocking report that something is running.
///
/// The question is "tell the user this is happening, without taking the
/// application away from them". Material draws a top-edge line, Fluent a
/// page-top `ProgressBar` or an `InfoBar`, macOS a `ProgressBar` in the
/// toolbar area - so the application states the fact and never the placement.
@immutable
final class ActivitySpec {
  /// Declares the running operation.
  const ActivitySpec({
    required this.operation,
    this.currentStep,
    this.totalSteps,
    this.indeterminate = true,
    this.onShowDetail,
  });

  /// What is running, in words: "Fetching origin".
  final String operation;

  /// Which step it is on, where the operation has countable steps.
  final int? currentStep;

  /// How many steps there are, where that is known.
  final int? totalSteps;

  /// Whether the end is unknowable. True means the skin must not imply
  /// progress it cannot honour.
  final bool indeterminate;

  /// How to open the full account of what is happening. Null means there is
  /// nothing more to show.
  final VoidCallback? onShowDetail;
}

/// An operation the user must wait for.
///
/// A nullable slot rather than a member, because "blocking progress is a
/// route" is exactly the decision the three languages make differently -
/// Material an in-shell scrim, Fluent a `ContentDialog` with a `ProgressRing`,
/// macOS a `MacosSheet`. The application is already declarative here: the
/// overlay is driven by a provider, so it states the fact and lets the skin
/// choose route versus layer.
@immutable
final class BlockingProgressSpec {
  /// Declares the blocking operation.
  const BlockingProgressSpec({
    required this.operation,
    this.fraction,
    this.currentStep,
    this.totalSteps,
    this.detail,
  });

  /// What is running, in words.
  final String operation;

  /// How far along, from 0 to 1, or null when that is unknowable.
  final double? fraction;

  /// Which step it is on, where the operation has countable steps.
  final int? currentStep;

  /// How many steps there are, where that is known.
  final int? totalSteps;

  /// The current sub-step, in words: the file being written, the ref being
  /// pushed.
  final String? detail;
}

/// What the whole application window contains.
@immutable
final class ShellSpec {
  /// Declares the shell.
  const ShellSpec({
    required this.identity,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.toolbar,
    required this.paneOrder,
    this.density,
    this.onDensityChanged,
    this.aside,
    this.banner,
    this.status,
    this.activity,
    this.blocking,
  });

  /// Who this application is. Required because macOS's own dialog is.
  final AppIdentity identity;

  /// Everywhere the user can go.
  final List<ShellDestination> destinations;

  /// Where the user is.
  final int selectedIndex;

  /// How to tell the application the user went somewhere else.
  final ValueChanged<int> onSelect;

  /// The shell's actions, grouped and prioritised. THE SKIN decides what fits
  /// and what overflows.
  final List<ToolbarGroup> toolbar;

  /// The order the F6 / Shift+F6 cycle and the Tab key walk the regions in.
  ///
  /// This is WHAT THE USER CAN DO, so it is structure and the skin may not
  /// reorder it. `BaseFocusRegion` stays in application code and wraps AROUND
  /// whatever `chrome.shell` returns.
  final List<ShellPane> paneOrder;

  /// How much of the navigation the user has asked to see, or NULL meaning
  /// "this skin owns its own display mode".
  ///
  /// A skin whose canonical navigation ships a toggle leaves this alone and
  /// binds [onDensityChanged] to its own control. The application never draws
  /// a second one.
  final NavigationDensity? density;

  /// How to tell the application the user changed it.
  final ValueChanged<NavigationDensity>? onDensityChanged;

  /// The command-log region, or null while the application has none.
  final ShellAside? aside;

  /// A standing message across the top of the window, or null.
  final BannerSpec? banner;

  /// The standing status line, or null.
  final ShellStatus? status;

  /// A non-blocking report of something running, or null.
  final ActivitySpec? activity;

  /// An operation the user must wait for, or null.
  ///
  /// This slot and [activity] are two of the four homes that let
  /// `ShellSpec.layers` be deleted. A `List<ContentPort>` of arbitrary overlays
  /// was the contract's one uncovered hole: the attribution walk resumes
  /// inside a port, so every paint decision smuggled through one was attributed
  /// to the application, correctly and permanently. A future full-screen
  /// overlay must ask for a member rather than smuggle itself through a port.
  final BlockingProgressSpec? blocking;
}

/// The batch actions offered while several things are selected.
///
/// A nullable slot on the screen rather than a member, because a member would
/// let a screen mount the bar anywhere - and PLACEMENT is precisely where the
/// three languages diverge (a contextual bottom bar, a `CommandBar` plus an
/// `InfoBar`, a bottom `ToolBar`).
@immutable
final class SelectionBarSpec {
  /// Declares the current selection and what can be done to it.
  const SelectionBarSpec({
    required this.selectedCount,
    required this.onClear,
    required this.actions,
  });

  /// How many things are selected.
  final int selectedCount;

  /// How to drop the selection.
  final VoidCallback onClear;

  /// What can be done to all of them at once.
  final List<ToolbarGroup> actions;
}

/// What one screen contains.
@immutable
final class ScreenSpec {
  /// Declares a screen.
  const ScreenSpec({
    required this.title,
    required this.body,
    this.toolbar = const <ToolbarGroup>[],
    this.primaryActions = const <ToolbarActionEntry>[],
    this.selectionBar,
    this.banner,
    this.footer,
  });

  /// What this screen is called.
  final String title;

  /// What is on it.
  final ContentPort body;

  /// The screen's own actions. The same type as `ShellSpec.toolbar`, for the
  /// same reason: two of the three languages own overflow at the bar.
  final List<ToolbarGroup> toolbar;

  /// What this screen is FOR - the one or two things a user came here to do.
  ///
  /// The NEED behind this slot is Material's floating action button, and
  /// naming it `fab` would have shipped Material's answer to two languages
  /// that have none. "What are this screen's primary actions" is a question
  /// all three answer: Material with a FAB, Fluent with a `CommandBar` primary
  /// item, macOS with a `ToolBar` action.
  final List<ToolbarActionEntry> primaryActions;

  /// Non-null only while things are multi-selected.
  final SelectionBarSpec? selectionBar;

  /// A standing message across the top of this screen, or null.
  final BannerSpec? banner;

  /// A standing region along the bottom, or null.
  final ContentPort? footer;
}

/// One action at the bottom of a dialog, as data rather than as a widget.
///
/// Everything on it survives a change of design language: a string, a
/// callback, a role and two flags. Nothing names a class, a colour or a size,
/// so each language may put it on the other side of the row, stretch it to
/// equal width, or turn it into its own alert action.
@immutable
final class DialogAction {
  /// Declares one action.
  const DialogAction({
    required this.label,
    required this.onPressed,
    required this.role,
    this.icon,
    this.enabled = true,
    this.isLoading = false,
  });

  /// The action's words, and its accessible name. In the languages that stack
  /// actions full-width it is the only thing distinguishing them.
  final String label;

  /// What the action does. Null disables it.
  final VoidCallback? onPressed;

  /// What the action means. This is the single piece of information a widget
  /// list threw away, and the reason the type exists.
  final DialogActionRole role;

  /// An optional leading mark.
  final IconRole? icon;

  /// Whether the action may run right now. Distinct from a null [onPressed]
  /// only in how it reads at the call site: a confirmation waiting on a typed
  /// token says `enabled: _tokenMatches` and keeps its callback visible.
  final bool enabled;

  /// Whether the action is running, so the skin can show progress in its
  /// place. A loading action is never invokable.
  final bool isLoading;

  /// The resolved answer to "can the user invoke this now".
  bool get isEnabled => enabled && !isLoading && onPressed != null;
}

/// What a dialog is asking.
@immutable
final class DialogSpec {
  /// Declares a dialog.
  const DialogSpec({
    required this.title,
    required this.content,
    this.actions = const <DialogAction>[],
    this.icon,
    this.tone = Tone.neutral,
    this.extent = DialogExtent.form,
    this.barrierDismissible = true,
    this.onSubmit,
  });

  /// What the dialog is about.
  final String title;

  /// What it contains.
  final ContentPort content;

  /// The ways out, in reading order. The order given here is the order the
  /// application means; a language that arranges them differently derives its
  /// own order from the roles rather than from the position in this list.
  ///
  /// At most one action may be [DialogActionRole.affirmative]. That invariant
  /// is asserted where the dialog is presented rather than here, because a
  /// `const` constructor cannot evaluate it.
  final List<DialogAction> actions;

  /// A mark beside the title.
  final IconRole? icon;

  /// What the dialog means: an ordinary question, a warning, a destruction.
  final Tone tone;

  /// What KIND of thing the dialog contains - which is what a skin needs in
  /// order to choose between an alert and a sheet, and what fifteen call sites
  /// are approximating with a width today.
  final DialogExtent extent;

  /// Whether clicking outside completes the dialog. A statement about what the
  /// user may do, not about how the barrier looks.
  final bool barrierDismissible;

  /// The dialog's primary action, triggered by Enter from anywhere inside it.
  ///
  /// Left null for a dialog with no single primary action - or deliberately
  /// for one whose affirmative action destroys something, where Enter must
  /// never wave the loss through.
  final VoidCallback? onSubmit;
}

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// Button visual variants
enum ButtonVariant {
  /// Filled with primary color - for primary actions
  primary,

  /// Outlined with secondary color - for secondary actions
  secondary,

  /// Text only, subtle - for tertiary actions
  tertiary,

  /// Red/destructive color - for dangerous actions
  danger,

  /// Transparent, hover only - for minimal actions
  ghost,

  /// Green/success color - for positive actions (git bisect good, success states)
  success,

  /// Red outlined - for destructive secondary actions
  dangerSecondary,
}

/// Button size variants
enum ButtonSize {
  /// Compact, for tight spaces
  small,

  /// Default size
  medium,

  /// Prominent actions
  large,
}

/// What the application's seven-value [ButtonVariant] means in the contract's
/// vocabulary, as an [Emphasis] and a [Tone].
///
/// The split is the contract's (`SKIN-CONTRACT.md` §2.4): `dangerSecondary`
/// was a *Material* compound, while "quiet, and destructive" is a meaning
/// three design languages can each answer their own way. The mapping is exact
/// and total, which is what makes the delegation below pixel-neutral — the
/// same table is written out at the skin's own `MaterialControls`, and the two
/// must stay in step.
///
/// `ButtonVariant` itself survives this phase deliberately: it is the word
/// 130-odd call sites already use, and rewriting them is a separate,
/// judgement-carrying pass. What has moved is the *answer* to what a variant
/// looks like, which now lives entirely inside the skin.
({Emphasis emphasis, Tone tone}) _meaningOf(ButtonVariant variant) =>
    switch (variant) {
      ButtonVariant.primary => (emphasis: Emphasis.primary, tone: Tone.accent),
      ButtonVariant.danger => (emphasis: Emphasis.primary, tone: Tone.danger),
      ButtonVariant.success => (emphasis: Emphasis.primary, tone: Tone.success),
      ButtonVariant.secondary => (
        emphasis: Emphasis.secondary,
        tone: Tone.accent,
      ),
      ButtonVariant.dangerSecondary => (
        emphasis: Emphasis.secondary,
        tone: Tone.danger,
      ),
      ButtonVariant.tertiary => (emphasis: Emphasis.link, tone: Tone.accent),
      ButtonVariant.ghost => (emphasis: Emphasis.quiet, tone: Tone.neutral),
    };

/// How much room a [ButtonSize] is entitled to, in the contract's words.
ControlScale _scaleOf(ButtonSize size) => switch (size) {
  ButtonSize.small => ControlScale.compact,
  ButtonSize.medium => ControlScale.normal,
  ButtonSize.large => ControlScale.prominent,
};

/// Base button component for all button patterns in the app.
///
/// **This is a façade** (#249, §2.11): the constructor is the one ~130 call
/// sites already write, and the body is one delegation to `controls.button`.
/// Everything the button used to draw itself — the three Material button
/// classes it maps onto, the per-size container, label style and glyph size,
/// the per-variant `styleFrom` colours with their M3 state-layer opacities,
/// the shared disabled treatment and the loading spinner — moved into the
/// Material skin verbatim, together with the comments recording why each one
/// is the way it is (`packages/gitui_skin_material/lib/src/facets/material_controls.dart`,
/// member `button`). The BTN-001..BTN-006 deviation entries and
/// `packages/gitui_skin_material/test/conformance/components/base_button_conformance_test.dart`
/// measure what this renders, so they keep measuring the same pixels through
/// the delegation.
///
/// What stays here is the two things that are the application's and not a
/// design language's: *what the button says* ([label]) and *what pressing it
/// does* ([onPressed]) — plus the two vocabularies 130 call sites speak in,
/// [ButtonVariant] and [ButtonSize], which are translated into the contract's
/// [Emphasis] × [Tone] and [ControlScale] by the two tables above.
///
/// ## Icon Guidelines
/// - Use leading icons for actions (check, plus, arrow)
/// - Use trailing icons for navigation/expansion (arrowRight, caretDown)
/// - Icons name a MEANING ([IconRole]), never a glyph: which mark stands for
///   that meaning, and at which weight, is the skin's answer
///
/// Example usage:
/// ```dart
/// // Primary action with leading icon
/// BaseButton(
///   label: 'Commit Changes',
///   variant: ButtonVariant.primary,
///   size: ButtonSize.medium,
///   leadingIcon: IconRole.check,
///   onPressed: () => commitChanges(),
/// )
///
/// // Destructive action
/// BaseButton(
///   label: 'Discard All',
///   variant: ButtonVariant.danger,
///   leadingIcon: IconRole.trash,
///   onPressed: () => discardAll(),
/// )
///
/// // Loading state
/// BaseButton(
///   label: 'Saving...',
///   variant: ButtonVariant.primary,
///   isLoading: true,
///   onPressed: null,
/// )
/// ```
class BaseButton extends StatelessWidget {
  const BaseButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
  });

  /// Callback when button is pressed (null if disabled)
  final VoidCallback? onPressed;

  /// Button text label
  final String label;

  /// Visual variant (primary, secondary, tertiary, danger, ghost)
  final ButtonVariant variant;

  /// Size variant (small, medium, large)
  final ButtonSize size;

  /// The meaning of the mark before the words, or null for none.
  final IconRole? leadingIcon;

  /// The meaning of the mark after the words, or null for none.
  final IconRole? trailingIcon;

  /// Whether button is in loading state (shows spinner)
  final bool isLoading;

  /// Whether button is disabled
  final bool isDisabled;

  /// Whether button should expand to full width
  final bool fullWidth;

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        final ({Emphasis emphasis, Tone tone}) meaning = _meaningOf(variant);
        return skin.controls.button(
          inner,
          ButtonSpec(
            label: label,
            // The member disables itself for a null callback and while
            // loading; [isDisabled] is this façade's third way of saying the
            // same thing, so it is resolved here rather than duplicated in
            // the spec.
            onPressed: isDisabled ? null : onPressed,
            emphasis: meaning.emphasis,
            tone: meaning.tone,
            scale: _scaleOf(size),
            leading: leadingIcon,
            trailing: trailingIcon,
            isLoading: isLoading,
            fillWidth: fullWidth,
          ),
        );
      });
}

/// Icon-only button component for compact spaces.
///
/// **This is a façade** (#249, §2.11), on the same terms as [BaseButton]: the
/// body is one delegation to `controls.iconButton`, and the per-size
/// container and glyph, the per-variant colours, the ICO-001 control corner,
/// the selected recolouring and the padded tap target all moved into the
/// Material skin verbatim (`material_controls.dart`, member `iconButton`).
/// The ICO-001..ICO-005 deviation entries and
/// `packages/gitui_skin_material/test/conformance/components/base_icon_button_conformance_test.dart`
/// measure what this renders.
///
/// ## Usage Guidelines
/// - [tooltip] is required: it is the hover name of the action and the
///   semantic label a mark-only control has to carry (CLAUDE.md, and
///   `IconButtonSpec.tooltip` for the same reason)
/// - Use ghost variant (default) for toolbar buttons
/// - Use danger variant for destructive icon actions
/// - Use primary variant for affirmative icon actions
///
/// Example usage:
/// ```dart
/// // Toolbar button
/// BaseIconButton(
///   icon: IconRole.trash,
///   tooltip: 'Delete',
///   variant: ButtonVariant.ghost,
///   onPressed: () => deleteItem(),
/// )
///
/// // Destructive action
/// BaseIconButton(
///   icon: IconRole.x,
///   tooltip: 'Remove',
///   variant: ButtonVariant.danger,
///   size: ButtonSize.small,
///   onPressed: () => removeItem(),
/// )
/// ```
class BaseIconButton extends StatelessWidget {
  const BaseIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.variant = ButtonVariant.ghost,
    this.size = ButtonSize.medium,
    this.isDisabled = false,
    this.isSelected,
  });

  /// Callback when button is pressed (null if disabled)
  final VoidCallback? onPressed;

  /// The meaning the mark stands for.
  final IconRole icon;

  /// The action's name, shown on hover and read by assistive technology.
  final String tooltip;

  /// Visual variant
  final ButtonVariant variant;

  /// Size variant
  final ButtonSize size;

  /// Whether button is disabled
  final bool isDisabled;

  /// Marks a toggle-style button's state: null (the default) is a plain
  /// action button with no selected state, false a toggle that is currently
  /// off, and true a toggle that is on (e.g. a favorited star). The skin
  /// decides what "on" looks like — a tint, a heavier or solid mark, or both.
  final bool? isSelected;

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        final ({Emphasis emphasis, Tone tone}) meaning = _meaningOf(variant);
        return skin.controls.iconButton(
          inner,
          IconButtonSpec(
            icon: icon,
            tooltip: tooltip,
            onPressed: isDisabled ? null : onPressed,
            emphasis: meaning.emphasis,
            tone: meaning.tone,
            scale: _scaleOf(size),
            selected: isSelected,
          ),
        );
      });
}

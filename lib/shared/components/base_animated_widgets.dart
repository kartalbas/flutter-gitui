import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/config/app_config.dart';

// `BaseDropdownButton` stood here and is gone, on the precedent this
// migration already set for `searchable_dropdown.dart`: it had no call site
// anywhere in `lib/`, and a second façade over one member would be two ways
// to ask for one thing. Three ways, in fact - `controls.dropdown` is the
// member, `BaseDropdown` (base_dropdown.dart) is the application's own front
// door onto the field form of it, and this was a third door onto neither,
// taking ready-made `DropdownMenuItem`s (Material widgets crossing an
// application API) and rounding the menu itself. The corner it rounded died
// with the construction rather than moving, which is the only way a corner
// is allowed to leave: no application code is left that says how round a
// menu is.

/// Base popup menu button that respects animation speed settings.
///
/// **Two callers left, both kept by a recorded decision (#438).** Every other
/// menu in the application opens through `overlays.menuAnchor` now, where the
/// SKIN builds the trigger and the menu together; what remains here is the
/// quick-settings menu, whose colour-scheme rows lead with a seed-colour
/// swatch, and the language selector, whose rows lead with flag artwork -
/// per-row artwork the sealed `MenuEntry` set deliberately cannot carry.
///
/// The [iconSize] parameter is gone with the migration: every caller that
/// passed one now states its trigger through `MenuAnchorSpec`, and the two
/// that remain hand their own already-sized [BaseIcon] in, so the fallback had
/// nothing left to size. Nothing moves - `IconButton`'s M3 container is 40 dp
/// at both 20 and 24, and a [BaseIcon] carries its own measured size - which
/// is why the token read this line held could finally leave the register.
class BasePopupMenuButton<T> extends StatelessWidget {
  final Widget? icon;
  final String? tooltip;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final Offset offset;
  final bool enabled;
  final Widget? child;

  const BasePopupMenuButton({
    super.key,
    this.icon,
    this.tooltip,
    required this.itemBuilder,
    this.onSelected,
    this.onCanceled,
    this.offset = Offset.zero,
    this.enabled = true,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final animationSpeed =
        Theme.of(context).extension<AnimationSpeedExtension>()?.speed ??
        AppAnimationSpeed.normal;

    return PopupMenuButton<T>(
      icon: icon,
      tooltip: tooltip,
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      onCanceled: onCanceled,
      offset: offset,
      enabled: enabled,
      popUpAnimationStyle: AnimationStyle(
        duration: AppTheme.getStandardAnimation(animationSpeed),
      ),
      child: child,
    );
  }
}

/// Base switch that respects animation speed settings
class BaseSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeThumbColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;

  const BaseSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeThumbColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
  });

  @override
  Widget build(BuildContext context) {
    // Note: Switch widget doesn't have a direct animation duration parameter
    // The animation is handled internally by Material, but we can control it
    // through the MaterialStateProperty if needed in future Flutter versions
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: _resolvePerState(activeThumbColor, inactiveThumbColor),
      trackColor: _resolvePerState(activeTrackColor, inactiveTrackColor),
    );
  }

  /// Resolves the caller's colors per state: the active color only while
  /// selected, the inactive color otherwise. Disabled states resolve to null
  /// so the theme's disabled treatment stays intact, and when neither color
  /// is given the property itself is null, leaving the theme in full control.
  static WidgetStateProperty<Color?>? _resolvePerState(
    Color? active,
    Color? inactive,
  ) {
    if (active == null && inactive == null) return null;
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;
      return states.contains(WidgetState.selected) ? active : inactive;
    });
  }
}

/// Base checkbox that respects animation speed settings
class BaseCheckbox extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Color? activeColor;
  final Color? checkColor;
  final bool tristate;

  const BaseCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.checkColor,
    this.tristate = false,
  });

  @override
  Widget build(BuildContext context) {
    // Note: Checkbox widget doesn't have a direct animation duration parameter
    // The animation is handled internally by Material
    return Checkbox(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      checkColor: checkColor,
      tristate: tristate,
    );
  }
}

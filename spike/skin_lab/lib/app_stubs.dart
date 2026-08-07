// Stand-ins for the application symbols the frozen component copies reference,
// so those copies keep their bodies byte-identical to the sources they were
// taken from while compiling inside this throwaway package.
//
// This file is the ONLY substitution the spike makes, and it is deliberately
// made at the *import* level rather than inside the frozen bodies: nothing here
// changes a single statement of a component under test. Every stub reproduces
// the real value (see the `source:` note on each), because a wrong token value
// would silently change what the skins are measured against.
//
// Nothing in here is part of the measurement. The measurement is what the
// skins in lib/skins/ can and cannot do with the frozen public signatures.
library;

import 'package:flutter/material.dart';

/// source: lib/shared/theme/app_theme.dart:430-469 (values copied verbatim).
abstract final class AppTheme {
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  static const double radiusXS = 2.0;
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;

  static const double iconXS = 12.0;
  static const double iconS = 16.0;
  static const double iconM = 20.0;
  static const double iconL = 24.0;
  static const double iconXL = 32.0;
}

/// source: lib/core/constants/app_constants.dart:23-24.
abstract final class AppConstants {
  static const double defaultDialogWidth = 650;
  static const double minDialogWidth = 300;
}

/// source: lib/shared/theme/ git semantic colors. Only `added` is reachable
/// from the components under test (the success button variant).
class GitSemanticColors {
  const GitSemanticColors();

  Color get added => const Color(0xFF4CAF50);

  static Color foregroundOn(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

extension GitColorsContext on BuildContext {
  GitSemanticColors get gitColors => const GitSemanticColors();
}

/// source: lib/shared/icons/phosphor_icons.dart. The spike maps the handful of
/// glyphs the frozen components name onto Material icons; the glyph identity
/// is irrelevant to whether a signature can drive a canonical widget.
abstract final class PhosphorIconsRegular {
  static const IconData x = Icons.close;
  static const IconData eye = Icons.visibility_outlined;
  static const IconData eyeSlash = Icons.visibility_off_outlined;
  static const IconData question = Icons.help_outline;
  static const IconData warning = Icons.warning_amber_outlined;
  static const IconData dotsThreeVertical = Icons.more_vert;
  static const IconData caretLeft = Icons.chevron_left;
  static const IconData caretRight = Icons.chevron_right;
  static const IconData gitBranch = Icons.account_tree_outlined;
  static const IconData folder = Icons.folder_outlined;
  static const IconData clockCounterClockwise = Icons.history;
  static const IconData gearSix = Icons.settings_outlined;
}

abstract final class PhosphorIconsBold {
  static const IconData gitBranch = Icons.account_tree;
}

/// source: lib/generated/app_localizations.dart. Only the strings the frozen
/// components read are stubbed; English only, because the spike measures
/// structure, not translation.
class AppLocalizations {
  const AppLocalizations();

  static AppLocalizations? of(BuildContext context) => const AppLocalizations();

  String get close => 'Close';
  String get clear => 'Clear';
  String get cancel => 'Cancel';
  String get confirm => 'Confirm';
  String get delete => 'Delete';
  String get showPassword => 'Show password';
  String get hidePassword => 'Hide password';
  String get moreActions => 'More actions';
  String get appTitle => 'Flutter GitUI';
  String get collapse => 'Collapse';
  String get expand => 'Expand';
}

/// source: lib/shared/components/base_label.dart. The label layer is a thin
/// typography wrapper and is not itself under test; only the roles the frozen
/// components use are stubbed.
class HeadlineSmallLabel extends StatelessWidget {
  const HeadlineSmallLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
  );
}

class TitleMediumLabel extends StatelessWidget {
  const TitleMediumLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
  );
}

class BodyMediumLabel extends StatelessWidget {
  const BodyMediumLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
  );
}

/// source: lib/shared/components/base_menu_item.dart:210-240.
class MenuItemLabel extends StatelessWidget {
  const MenuItemLabel(this.text, {super.key, this.color, this.fontWeight});

  final String text;
  final Color? color;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: color, fontWeight: fontWeight),
  );
}

/// source: lib/shared/components/base_animated_widgets.dart:63-65. Reproduced
/// because its `itemBuilder` is where `List<PopupMenuEntry<dynamic>>` is
/// consumed - Probe A's subject.
class BasePopupMenuButton<T> extends StatelessWidget {
  const BasePopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.icon,
    this.tooltip,
    this.onSelected,
  });

  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final Widget? icon;
  final String? tooltip;
  final PopupMenuItemSelected<T>? onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    itemBuilder: itemBuilder,
    icon: icon,
    tooltip: tooltip,
    onSelected: onSelected,
  );
}

/// source: lib/shared/utils/keyboard_guards.dart. The real predicate inspects
/// the primary-focused editable; the spike only needs it to compile and to
/// answer "no" in tests.
bool focusedEditableOwnsKey(KeyEvent event) {
  final Object? focused = FocusManager.instance.primaryFocus?.context?.widget;
  return focused is EditableText && focused.maxLines != 1;
}

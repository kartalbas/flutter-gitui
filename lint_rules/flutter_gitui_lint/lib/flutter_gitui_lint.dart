import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/lints/avoid_filled_button.dart';
import 'src/lints/avoid_text_button.dart';
import 'src/lints/avoid_elevated_button.dart';
import 'src/lints/avoid_outlined_button.dart';
import 'src/lints/avoid_icon_button.dart';
import 'src/lints/avoid_list_tile.dart';
import 'src/lints/avoid_text_field.dart';
import 'src/lints/avoid_dropdown_button_form_field.dart';
import 'src/lints/avoid_simple_dialog.dart';
import 'src/lints/avoid_alert_dialog.dart';
import 'src/lints/avoid_dialog.dart';
import 'src/lints/avoid_card.dart';
import 'src/lints/avoid_chip.dart';
import 'src/lints/avoid_filter_chip.dart';
import 'src/lints/avoid_action_chip.dart';
import 'src/lints/avoid_choice_chip.dart';
import 'src/lints/avoid_badge.dart';
import 'src/lints/avoid_hardcoded_spacing.dart';
import 'src/lints/avoid_hardcoded_radius.dart';
import 'src/lints/avoid_hardcoded_colors.dart';
import 'src/lints/avoid_text_with_style.dart';
import 'src/lints/avoid_null_color_in_copy_with.dart';
import 'src/lints/avoid_print.dart';
import 'src/lints/avoid_raw_shortcuts.dart';
import 'src/lints/no_value_in_contract.dart';
import 'src/lints/no_widget_in_contract.dart';
import 'src/lints/require_confirm_destructive.dart';
import 'src/lints/token_read_is_mechanical.dart';

/// Flutter GitUI custom lint rules
///
/// Enforces Base* component usage and design system consistency.
PluginBase createPlugin() => _FlutterGitUILint();

class _FlutterGitUILint extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    // Button lints
    AvoidFilledButton(),
    AvoidTextButton(),
    AvoidElevatedButton(),
    AvoidOutlinedButton(),
    AvoidIconButton(),

    // List lints
    AvoidListTile(),

    // Form lints
    AvoidTextField(),
    AvoidDropdownButtonFormField(),

    // Dialog lints
    AvoidSimpleDialog(),
    AvoidAlertDialog(),
    AvoidDialog(),

    // Card lints
    AvoidCard(),

    // Chip/Badge lints
    AvoidChip(),
    AvoidFilterChip(),
    AvoidActionChip(),
    AvoidChoiceChip(),
    AvoidBadge(),

    // Theme lints
    AvoidHardcodedSpacing(),
    AvoidHardcodedRadius(),
    AvoidHardcodedColors(),

    // Typography lints
    AvoidTextWithStyle(),
    AvoidNullColorInCopyWith(),

    // Logging lints
    AvoidPrint(),

    // Keyboard lints
    AvoidRawShortcuts(),

    // Safety lints
    RequireConfirmDestructive(),

    // Skin-contract lints (#249). They guard the two properties the whole
    // design rests on and that nothing else can check: that no contract member
    // names a design value, and that a Widget crosses into a skin only as a
    // ContentPort. Both are scoped to packages/gitui_skin_api and both are
    // permanent - unlike the migration classifiers below, they have no end
    // date, because the contract they guard does not.
    NoValueInContract(),
    NoWidgetInContract(),

    // Migration classifiers. These measure a migration in progress rather than
    // guarding an invariant, so they are off by default (see the rule's
    // `enabledByDefault`) and they are deleted when their migration lands.
    // token_read_is_mechanical goes at P6 of #249.
    TokenReadIsMechanical(),
  ];
}

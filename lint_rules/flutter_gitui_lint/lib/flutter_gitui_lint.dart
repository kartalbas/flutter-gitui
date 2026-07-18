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
import 'src/lints/avoid_hardcoded_colors.dart';
import 'src/lints/avoid_text_with_style.dart';
import 'src/lints/avoid_null_color_in_copy_with.dart';
import 'src/lints/avoid_print.dart';

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
        AvoidHardcodedColors(),

        // Typography lints
        AvoidTextWithStyle(),
        AvoidNullColorInCopyWith(),

        // Logging lints
        AvoidPrint(),
      ];
}

import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Bans raw `ChoiceChip` constructions outside the Base component layer.
///
/// The rule survives the move from `BaseChoiceChip` to `BaseChoiceGroup`, and
/// matters more after it than before. `ChoiceChip` is still the widget Material
/// draws one option of a group with, so the ban still has a subject; what
/// changed is where it sends people. A row of hand-assembled `ChoiceChip`s is
/// now wrong twice over — it reaches past the Base layer, *and* it rebuilds by
/// hand the grouping that no other design language can take apart again. The
/// only construction left is the one inside
/// `lib/shared/components/base_filter_chip.dart`, which suppresses this rule at
/// that single line, plus the oracle in the chip conformance suite.
class AvoidChoiceChip extends DartLintRule {
  const AvoidChoiceChip() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_choice_chip',
    problemMessage:
        'Avoid using ChoiceChip directly. Single choice is a group, not a '
        'chip: use BaseChoiceGroup with a ChoiceOption per choice.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;

      if (type.element?.name == 'ChoiceChip') {
        reporter.atNode(node, code);
      }
    });
  }
}

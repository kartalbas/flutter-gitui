import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidChoiceChip extends DartLintRule {
  const AvoidChoiceChip() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_choice_chip',
    problemMessage:
        'Avoid using ChoiceChip directly. Use BaseFilterChip with single selection logic instead.',
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

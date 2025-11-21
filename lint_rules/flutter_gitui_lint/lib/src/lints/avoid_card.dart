import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidCard extends DartLintRule {
  const AvoidCard() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_card',
    problemMessage:
        'Avoid using Card directly. Use BaseCard instead for consistent styling.',
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

      if (type.element?.name == 'Card') {
        reporter.atNode(node, code);
      }
    });
  }
}

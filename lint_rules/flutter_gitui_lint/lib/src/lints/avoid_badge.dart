import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidBadge extends DartLintRule {
  const AvoidBadge() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_badge',
    problemMessage:
        'Avoid using Badge directly. Use BaseBadge or BaseNumericBadge instead for consistent styling.',
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

      if (type.element?.name == 'Badge') {
        reporter.atNode(node, code);
      }
    });
  }
}

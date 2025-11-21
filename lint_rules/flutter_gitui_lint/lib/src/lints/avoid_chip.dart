import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidChip extends DartLintRule {
  const AvoidChip() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_chip',
    problemMessage:
        'Avoid using Chip directly. Use BaseBadge for display-only badges.',
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

      if (type.element?.name == 'Chip') {
        reporter.atNode(node, code);
      }
    });
  }
}

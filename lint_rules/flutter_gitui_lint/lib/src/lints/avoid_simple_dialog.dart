import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidSimpleDialog extends DartLintRule {
  const AvoidSimpleDialog() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_simple_dialog',
    problemMessage:
        'Avoid using SimpleDialog. Use BaseDialog for consistent dialog styling.',
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

      if (type.element?.name == 'SimpleDialog') {
        reporter.atNode(node, code);
      }
    });
  }
}

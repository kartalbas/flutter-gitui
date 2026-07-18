import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidAlertDialog extends DartLintRule {
  const AvoidAlertDialog() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_alert_dialog',
    problemMessage:
        'Avoid using AlertDialog. Use BaseDialog for consistent dialog styling.',
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

      if (type.element?.name == 'AlertDialog') {
        reporter.atNode(node, code);
      }
    });
  }
}

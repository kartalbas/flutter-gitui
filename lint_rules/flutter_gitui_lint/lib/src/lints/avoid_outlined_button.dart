import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidOutlinedButton extends DartLintRule {
  const AvoidOutlinedButton() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_outlined_button',
    problemMessage:
        'Avoid using OutlinedButton. Use BaseButton with ButtonVariant.secondary instead.',
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

      if (type.element?.name == 'OutlinedButton') {
        reporter.atNode(node, code);
      }
    });
  }
}

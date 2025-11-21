import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidElevatedButton extends DartLintRule {
  const AvoidElevatedButton() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_elevated_button',
    problemMessage:
        'Avoid using ElevatedButton. Use BaseButton with ButtonVariant.primary instead.',
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

      if (type.element?.name == 'ElevatedButton') {
        reporter.atNode(node, code);
      }
    });
  }
}

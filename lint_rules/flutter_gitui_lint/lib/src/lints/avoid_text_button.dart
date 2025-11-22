import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidTextButton extends DartLintRule {
  const AvoidTextButton() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_text_button',
    problemMessage:
        'Avoid using TextButton. Use BaseButton with ButtonVariant.tertiary instead.',
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

      if (type.element?.name == 'TextButton') {
        reporter.atNode(node, code);
      }
    });
  }
}

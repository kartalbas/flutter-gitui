import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidIconButton extends DartLintRule {
  const AvoidIconButton() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_icon_button',
    problemMessage:
        'Avoid using IconButton. Use BaseButton with leadingIcon parameter instead.',
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

      if (type.element?.name == 'IconButton') {
        reporter.atNode(node, code);
      }
    });
  }
}

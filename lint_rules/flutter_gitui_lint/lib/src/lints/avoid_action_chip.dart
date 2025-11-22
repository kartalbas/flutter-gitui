import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidActionChip extends DartLintRule {
  const AvoidActionChip() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_action_chip',
    problemMessage:
        'Avoid using ActionChip directly. Use BaseActionChip instead for consistent styling.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Skip base component files
    final filePath = resolver.path;
    if (filePath.contains('/base_') || filePath.contains('\\base_')) {
      return;
    }

    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;

      if (type.element?.name == 'ActionChip') {
        reporter.atNode(node, code);
      }
    });
  }
}

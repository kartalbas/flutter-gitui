import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidListTile extends DartLintRule {
  const AvoidListTile() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_list_tile',
    problemMessage:
        'Avoid using ListTile. Use BaseListItem for consistent list item styling.',
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

      if (type.element?.name == 'ListTile') {
        reporter.atNode(node, code);
      }
    });
  }
}

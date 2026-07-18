import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidPrint extends DartLintRule {
  const AvoidPrint() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_print',
    problemMessage:
        'Avoid using print(). Use Logger.debug(), Logger.info(), Logger.error(), or Logger.warning() from logger_service.dart instead.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      // Check for print() function calls
      if (node.methodName.name == 'print' && node.target == null) {
        reporter.atNode(node, code);
      }
    });
  }
}

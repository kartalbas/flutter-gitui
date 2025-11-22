import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidHardcodedColors extends DartLintRule {
  const AvoidHardcodedColors() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_hardcoded_colors',
    problemMessage:
        'Avoid using hardcoded colors from Colors class. Use Theme.of(context).colorScheme or AppTheme color constants instead.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((node) {
      // Check for Colors.* usage
      if (node.prefix.name == 'Colors') {
        reporter.atNode(node, code);
      }
    });

    context.registry.addPropertyAccess((node) {
      // Check for Colors.* usage in property access
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'Colors') {
        reporter.atNode(node, code);
      }
    });
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Lint rule to avoid using null color values in copyWith calls.
///
/// Using `color: null` in `.copyWith()` causes text to inherit unpredictable
/// default colors that may not be readable in all theme modes.
///
/// Instead, always use explicit theme colors or base label components.
class AvoidNullColorInCopyWith extends DartLintRule {
  const AvoidNullColorInCopyWith() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_null_color_in_copy_with',
    problemMessage:
        'Avoid using null for color in copyWith. Use explicit theme colors (colorScheme.onSurface) or base label components instead.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      // Check if this is a copyWith call
      if (node.methodName.name != 'copyWith') return;

      // Check for color: null argument
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          final expression = arg.expression;

          // Check for color: null or color: someCondition ? value : null
          if (name == 'color') {
            if (expression is NullLiteral) {
              // Direct null: color: null
              reporter.atNode(node, code);
              return;
            }

            if (expression is ConditionalExpression) {
              // Check for ternary with null: color: condition ? value : null
              if (expression.elseExpression is NullLiteral ||
                  expression.thenExpression is NullLiteral) {
                reporter.atNode(node, code);
                return;
              }
            }
          }
        }
      }
    });
  }
}

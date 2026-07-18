import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidHardcodedSpacing extends DartLintRule {
  const AvoidHardcodedSpacing() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_hardcoded_spacing',
    problemMessage:
        'Avoid hardcoded spacing values. Use AppTheme spacing constants (e.g., AppTheme.spacing8, AppTheme.spacing16) instead.',
  );

  static const _commonSpacingValues = {4, 8, 16, 24, 32};

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;

      final typeName = type.element?.name;
      if (typeName != 'SizedBox' && typeName != 'EdgeInsets') return;

      // Check all arguments for numeric literals with common spacing values
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression) {
          _checkExpression(argument.expression, reporter);
        } else {
          _checkExpression(argument, reporter);
        }
      }
    });
  }

  void _checkExpression(Expression expression, DiagnosticReporter reporter) {
    if (expression is DoubleLiteral) {
      final value = expression.value;
      if (_commonSpacingValues.contains(value.toInt())) {
        reporter.atNode(expression, code);
      }
    } else if (expression is IntegerLiteral) {
      final value = expression.value;
      if (value != null && _commonSpacingValues.contains(value)) {
        reporter.atNode(expression, code);
      }
    }
  }
}

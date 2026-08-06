import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags any numeric literal passed to a `BorderRadius`, `BorderRadiusDirectional`
/// or `Radius` constructor, and any non-radius `AppTheme` constant used there.
///
/// Unlike spacing, every literal is flagged: a corner radius either comes from
/// the `AppTheme.radiusXS/S/M/L/XL` scale or is derived from a size (for
/// example `size / 2` for a pill or circle), and both of those are
/// expressions, not literals. An `AppTheme` constant from another scale
/// (`paddingS`, ...) used as a radius is a category error: it only works while
/// the two scales happen to share a value, and ties the corner shape to an
/// unrelated design decision.
class AvoidHardcodedRadius extends DartLintRule {
  const AvoidHardcodedRadius() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_hardcoded_radius',
    problemMessage:
        'Avoid hardcoded border radius values. Use the AppTheme radius scale '
        '(AppTheme.radiusXS/S/M/L/XL = 2/4/8/12/16) instead; a padding '
        'constant is not a radius even when it shares the value.',
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

      final typeName = type.element?.name;
      if (typeName != 'BorderRadius' &&
          typeName != 'BorderRadiusDirectional' &&
          typeName != 'Radius') {
        return;
      }

      // Checking Radius as well covers every composite form: the inner
      // Radius.circular of BorderRadius.all/only/vertical/horizontal is its
      // own creation expression and is visited separately.
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
    if (expression is IntegerLiteral || expression is DoubleLiteral) {
      reporter.atNode(expression, code);
      return;
    }

    if (expression is PrefixedIdentifier &&
        expression.prefix.name == 'AppTheme' &&
        !expression.identifier.name.startsWith('radius')) {
      reporter.atNode(expression, code);
    }
  }
}

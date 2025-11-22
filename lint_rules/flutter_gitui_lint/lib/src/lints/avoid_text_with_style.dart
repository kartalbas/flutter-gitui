import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidTextWithStyle extends DartLintRule {
  const AvoidTextWithStyle() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_text_with_style',
    problemMessage:
        'Avoid using Text widget with custom TextStyle. Use BaseLabel components (e.g., BaseLabel.body, BaseLabel.heading) instead.',
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

      if (type.element?.name != 'Text') return;

      // Check if there's a 'style' parameter
      Expression? styleArg;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'style') {
          styleArg = arg.expression;
          break;
        }
      }

      if (styleArg == null) return;

      // Allow Text with explicit color in copyWith (dark mode safe)
      // The issue is null colors that don't adapt to dark mode
      if (_hasExplicitColorInCopyWith(styleArg)) {
        return;
      }

      reporter.atNode(node, code);
    });
  }

  /// Check if the style expression uses copyWith with an explicit color parameter
  bool _hasExplicitColorInCopyWith(Expression styleExpr) {
    // Handle chain like: Theme.of(context).textTheme.bodyLarge?.copyWith(...)
    if (styleExpr is MethodInvocation) {
      if (styleExpr.methodName.name == 'copyWith') {
        // Check if color is explicitly set (not null)
        for (final arg in styleExpr.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'color') {
            // Check if the value is explicitly provided (not null literal)
            final value = arg.expression;
            if (value is! NullLiteral) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }
}

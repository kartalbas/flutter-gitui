import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidTextField extends DartLintRule {
  const AvoidTextField() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_text_field',
    problemMessage:
        'Avoid using TextField or TextFormField. Use BaseTextField for consistent input styling.',
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
      if (typeName == 'TextField' || typeName == 'TextFormField') {
        // Allow TextField/TextFormField when using features BaseTextField doesn't support
        if (_usesUnsupportedFeatures(node)) {
          return;
        }
        reporter.atNode(node, code);
      }
    });
  }

  /// Check if the TextField uses features that BaseTextField doesn't support
  bool _usesUnsupportedFeatures(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        // BaseTextField doesn't support onTap
        if (name == 'onTap') {
          return true;
        }
        // Check if decoration has complex Widget-based suffixIcon/prefixIcon
        if (name == 'decoration') {
          final decorationExpr = arg.expression;
          if (decorationExpr is InstanceCreationExpression) {
            if (_hasComplexIconWidget(decorationExpr)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Check if InputDecoration has complex Widget icons (not just IconData)
  bool _hasComplexIconWidget(InstanceCreationExpression decoration) {
    for (final arg in decoration.argumentList.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (name == 'suffixIcon' || name == 'prefixIcon') {
          // If the icon is a Row, Column, or other complex widget, allow it
          final iconExpr = arg.expression;
          if (iconExpr is InstanceCreationExpression) {
            final iconType = iconExpr.staticType?.element?.name;
            // BaseTextField only accepts IconData, not Widgets like Row
            if (iconType == 'Row' || iconType == 'Column' || iconType == 'Stack') {
              return true;
            }
          }
        }
      }
    }
    return false;
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Lint rule to avoid using null color values in copyWith calls.
///
/// `color: null` in `TextStyle.copyWith()` is a no-op wearing a decision's
/// syntax: `copyWith` keeps the existing colour when handed null, so the
/// argument changes nothing while reading as if it reset something — and the
/// ternary form (`color: cond ? x : null`) silently keeps the old colour on
/// one branch, which is rarely what the author meant.
///
/// The guidance changed with #432. This rule used to answer "so name a
/// colour: `colorScheme.onSurface`" — which instructs the author to write
/// the exact read the tone contract deletes, and which
/// `avoid_text_with_style` now reports as a restated ambient colour. The
/// colour of a styled word is the ramp's
/// (`AppTheme._brightnessCorrectedTextTheme` applies the scheme's
/// `onSurface` to every step), so the fix is to delete the dead argument; a
/// colour that should *differ* from ambient is a `Tone`, stated through
/// `BaseLabel(role:, tone:)`.
class AvoidNullColorInCopyWith extends DartLintRule {
  const AvoidNullColorInCopyWith() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_null_color_in_copy_with',
    problemMessage:
        'color: null in TextStyle.copyWith is a no-op: copyWith keeps the '
        'existing colour when given null. Delete the argument — the '
        'text-theme ramp already carries the ambient foreground '
        '(AppTheme._brightnessCorrectedTextTheme). A colour that should '
        'differ from ambient is a Tone, stated through '
        'BaseLabel(role:, tone:).',
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

      // The guidance here is about text rendering, so it only holds for
      // TextStyle. Domain models pass `color: null` to mean "leave the existing
      // value unchanged", which is correct and must not be reported.
      if (node.realTarget?.staticType?.element?.name != 'TextStyle') return;

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

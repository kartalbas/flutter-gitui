import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidDialog extends DartLintRule {
  const AvoidDialog() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_dialog',
    problemMessage:
        'Avoid using Dialog directly. Use BaseDialog or BaseViewerDialog for consistent dialog styling with proper border radius and design system compliance.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Get the file path from the resolver
    final filePath = resolver.source.uri.path;

    // Allow Dialog usage in base dialog implementations and changelog dialog
    if (filePath.contains('base_dialog.dart') ||
        filePath.contains('base_viewer_dialog.dart') ||
        filePath.contains('changelog_dialog.dart')) {
      return;
    }

    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;

      if (type.element?.name == 'Dialog') {
        reporter.atNode(node, code);
      }
    });
  }
}

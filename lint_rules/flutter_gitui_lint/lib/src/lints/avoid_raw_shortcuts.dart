import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a `Shortcuts(...)` or `CallbackShortcuts(...)` construction outside
/// `lib/shared/`, so no feature can hand-roll a keyboard entry point that
/// bypasses the shared keyboard contract (issue #382).
///
/// The contract lives in the shared layer: the KeyboardNavigable* views and
/// their `additionalBindings`, `onSubmit` on BaseDialog/BaseViewerDialog, and
/// BaseDismissScope. All of them route every unmodified key through
/// `focusedEditableOwnsKey` (lib/shared/utils/keyboard_guards.dart), the
/// guard that keeps a binding from shadowing text a user is typing. A raw
/// Shortcuts widget at a call site fires its bindings unconditionally, so the
/// guard never runs - which is exactly the drift this rule stops.
///
/// A genuinely global surface that must bind keys raw (today: only the app
/// shell's Ctrl/Meta chord map) is sanctioned by a two-place act, so an
/// exception can never happen in passing:
///
/// 1. the construction carries a marker comment directly above it (or above
///    its enclosing statement) naming why the surface is safe:
///
///        // sanctioned-shortcuts: the shell's global chord map; every
///        // binding is a Ctrl/Meta chord, so it cannot shadow text input.
///
/// 2. the file is listed in [_sanctionedFiles] below, so the exception is
///    reviewed next to the rule it weakens.
///
/// A marker without the snapshot entry (or vice versa) still fails, and the
/// marker is greppable (`grep -rn "sanctioned-shortcuts:" lib/`), so every
/// allowed site stays visible instead of becoming a silent bypass.
class AvoidRawShortcuts extends DartLintRule {
  const AvoidRawShortcuts() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_raw_shortcuts',
    problemMessage:
        'Avoid constructing Shortcuts/CallbackShortcuts outside lib/shared. '
        'Raw shortcut widgets bypass the shared keyboard contract - above '
        'all focusedEditableOwnsKey, the guard that keeps a binding from '
        'shadowing text a user is typing. Use the shared layer instead '
        '(additionalBindings on the KeyboardNavigable* views, onSubmit on '
        'BaseDialog/BaseViewerDialog, BaseDismissScope), or extend it. A '
        'genuinely global surface needs a "// sanctioned-shortcuts: '
        '<reason>" marker AND an entry in the sanctioned-files snapshot in '
        'lint_rules/flutter_gitui_lint/lib/src/lints/avoid_raw_shortcuts.dart.',
  );

  /// Reported when a sanctioned-shortcuts marker sits in a file that is not
  /// in [_sanctionedFiles], so a marker alone can never sanction a site.
  static const _unlistedFileCode = LintCode(
    name: 'avoid_raw_shortcuts',
    problemMessage:
        'A sanctioned-shortcuts marker alone does not sanction this file. '
        'Sanctioning is a two-place act so it cannot happen in passing: keep '
        'the marker naming why this surface may bind keys raw, and add the '
        'file to the sanctioned-files snapshot in '
        'lint_rules/flutter_gitui_lint/lib/src/lints/avoid_raw_shortcuts.dart.',
  );

  /// Files allowed to carry a `// sanctioned-shortcuts:` marker. Today only
  /// the app shell: its chord map is the app's one global shortcut surface,
  /// and every binding there is a Ctrl/Meta chord, which no editable and no
  /// navigable collection interprets - so the guard has nothing to protect.
  static const Set<String> _sanctionedFiles = {
    '/core/navigation/app_shell.dart',
  };

  /// The widgets that open a raw keyboard entry point.
  static const Set<String> _rawShortcutWidgets = {
    'Shortcuts',
    'CallbackShortcuts',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.source.uri.path;

    // The shared layer implements the keyboard contract and is the one place
    // the raw widgets may appear; tests may construct them to build fixture
    // key surfaces around the widget under test.
    if (filePath.contains('flutter_gitui/shared/') ||
        filePath.contains('/lib/shared/') ||
        filePath.contains('/test/')) {
      return;
    }

    final isSanctionedFile = _sanctionedFiles.any(filePath.endsWith);

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.staticType?.element?.name;
      if (typeName == null || !_rawShortcutWidgets.contains(typeName)) {
        return;
      }

      if (_hasSanctionMarker(node)) {
        if (!isSanctionedFile) {
          reporter.atNode(node, _unlistedFileCode);
        }
        return;
      }

      reporter.atNode(node, _code);
    });
  }

  /// Matches `// sanctioned-shortcuts: <non-empty text>` in the comment
  /// lines directly above the construction - at any nesting level between
  /// the constructor itself and its enclosing statement, so the marker sits
  /// beside the widget whether it is `return CallbackShortcuts(` or a
  /// `child: CallbackShortcuts(` deep in a build tree.
  static final RegExp _marker = RegExp(r'^///?\s*sanctioned-shortcuts:\s*\S');

  bool _hasSanctionMarker(InstanceCreationExpression node) {
    for (AstNode? current = node; current != null; current = current.parent) {
      for (
        Token? comment = current.beginToken.precedingComments;
        comment != null;
        comment = comment.next
      ) {
        if (_marker.hasMatch(comment.lexeme)) return true;
      }
      if (current is Statement) break;
    }
    return false;
  }
}

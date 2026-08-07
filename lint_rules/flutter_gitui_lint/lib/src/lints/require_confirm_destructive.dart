import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a call to a destructive `GitService`/`GitActions` method (the ones
/// catalogued in `DestructiveAction`) whose enclosing function does not also
/// call `confirmDestructive`, so a destructive git action cannot silently
/// bypass the single confirmation gate (issue #309).
///
/// What counts as guarded is deliberately lexical, not data-flow: the call is
/// accepted when the OUTERMOST enclosing function body (the method, or the
/// callback closure when the code sits in a field initializer such as the
/// GitCommands list) contains a `confirmDestructive(...)` invocation anywhere.
/// This catches the real failure mode - forgetting the gate entirely - without
/// false alarms for the established call shapes (guard first, destructive call
/// inside a nested `invoke:` closure or an `if (confirmed)` block).
///
/// When the confirmation genuinely lives elsewhere (a dedicated confirming
/// dialog, or a guard one call frame up), the call site must carry a marker
/// comment on the line(s) directly above its statement naming that place:
///
///     // confirmed-by: DeleteBranchDialog above; it collects the force
///     // choice and confirms.
///
/// The marker requires non-empty text after `confirmed-by:` and is greppable
/// (`grep -rn "confirmed-by:" lib/`), so every exception stays visible and
/// reviewable instead of becoming a silent bypass. A marker may only sit in
/// the same user-facing flow as the confirmation it names - the widget or
/// dialog file where the user actually acted - never in a shared helper or
/// service wrapper: a marker on a wrapper would invisibly exempt every future
/// caller of that wrapper.
///
/// The rule also watches the `DestructiveAction` enum itself: a constant that
/// is not in its hardcoded snapshot is reported, so extending the catalogue
/// without extending this rule is a build error rather than silent drift.
class RequireConfirmDestructive extends DartLintRule {
  const RequireConfirmDestructive() : super(code: _code);

  static const _code = LintCode(
    name: 'require_confirm_destructive',
    problemMessage:
        'This destructive git call is not guarded by confirmDestructive in '
        'its enclosing function. Route it through confirmDestructive '
        '(lib/shared/dialogs/confirm_destructive.dart), or - if the '
        'confirmation happens elsewhere - add a "// confirmed-by: <where>" '
        'marker comment directly above this statement naming it.',
  );

  /// Reported on a `DestructiveAction` constant missing from
  /// [_knownActions], so the hand-maintained destructive set below cannot
  /// silently drift behind the catalogue.
  static const _enumDriftCode = LintCode(
    name: 'require_confirm_destructive',
    problemMessage:
        'New DestructiveAction constant not covered by the '
        'require_confirm_destructive rule. Add its GitService/GitActions '
        'method(s) to the destructive set and its name to the enum snapshot '
        'in lint_rules/flutter_gitui_lint/lib/src/lints/'
        'require_confirm_destructive.dart.',
  );

  /// Methods on GitService/GitActions that are destructive on every call.
  /// Keep in sync with the DestructiveAction catalogue
  /// (lib/core/git/destructive_action.dart).
  static const Set<String> _alwaysDestructive = {
    // newCommit tier
    'revertCommit', 'cherryPickCommit',
    // reflogRecoverable tier
    'resetToCommit', 'amendCommit', 'squashCommits',
    'rebaseBranch', 'deleteBranch', 'deleteTag', 'deleteTags',
    // permanent tier
    'discardFile', 'discardFiles', 'discardAll',
    'deleteUntrackedFile', 'deleteUntrackedFiles',
    'dropStash', 'clearStashes',
    // remotePermanent tier
    'deleteRemoteBranch', 'deleteRemoteTag',
  };

  /// Snapshot of the `DestructiveAction` enum constants this rule covers.
  /// A constant in the enum but not here trips [_enumDriftCode]: whoever adds
  /// an action must add its method(s) to [_alwaysDestructive] (or the
  /// argument-dependent checks in [_isDestructiveCall]) and extend this set.
  static const Set<String> _knownActions = {
    // newCommit tier
    'revert', 'cherryPick',
    // reflogRecoverable tier
    'resetSoft', 'resetMixed', 'amend', 'squash', 'rebase',
    'deleteLocalBranch', 'deleteLocalTag',
    // permanent tier
    'resetHard', 'cleanWorkingDirectory', 'discardFile', 'discardAll',
    'deleteUntrackedFile', 'dropStash', 'clearStashes',
    // remotePermanent tier
    'forcePush', 'deleteRemoteBranch', 'deleteRemoteTag',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.source.uri.path;

    // Enum-drift tripwire: the destructive set above is a hand-maintained
    // mirror of the DestructiveAction catalogue, so a new constant must fail
    // the build until this rule learns its method(s). The catalogue file
    // contains no git calls of its own, so nothing else applies there.
    if (filePath.endsWith('/core/git/destructive_action.dart')) {
      context.registry.addEnumDeclaration((node) {
        if (node.name.lexeme != 'DestructiveAction') return;
        for (final constant in node.constants) {
          if (!_knownActions.contains(constant.name.lexeme)) {
            reporter.atNode(constant, _enumDriftCode);
          }
        }
      });
      return;
    }

    // The two layers that implement and forward the destructive methods are
    // the callees of every guarded call and cannot guard themselves. Tests
    // exercise the methods directly against fixture repositories.
    if (filePath.contains('/core/git/git_service.dart') ||
        filePath.contains('/core/git/git_providers.dart') ||
        filePath.contains('/test/')) {
      return;
    }

    context.registry.addMethodInvocation((node) {
      if (!_isDestructiveCall(node)) return;

      final targetTypeName = node.realTarget?.staticType?.element?.name;
      if (targetTypeName != 'GitService' && targetTypeName != 'GitActions') {
        return;
      }

      if (_enclosingScopeContainsGuard(node)) return;
      if (_hasConfirmedByMarker(node)) return;

      reporter.atNode(node, _code);
    });
  }

  /// Whether this invocation performs a destructive action. Three methods are
  /// only destructive for certain arguments and are checked structurally:
  /// - `cleanWorkingDirectory(dryRun: true)` only lists what would be removed;
  /// - `push`/`pushRemote` are only destructive when a `force:` argument is
  ///   present that is not the literal `false`;
  /// - `commit` is only destructive (amend) when an `amend:` argument is
  ///   present that is not the literal `false`.
  /// A non-literal `force:`/`amend:` value counts as destructive, because the
  /// call CAN take the destructive path at runtime.
  bool _isDestructiveCall(MethodInvocation node) {
    final name = node.methodName.name;

    if (name == 'cleanWorkingDirectory') {
      final dryRun = _namedArgument(node, 'dryRun');
      return !(dryRun is BooleanLiteral && dryRun.value);
    }
    if (name == 'push' || name == 'pushRemote') {
      final force = _namedArgument(node, 'force');
      if (force == null) return false;
      return !(force is BooleanLiteral && !force.value);
    }
    if (name == 'commit') {
      final amend = _namedArgument(node, 'amend');
      if (amend == null) return false;
      return !(amend is BooleanLiteral && !amend.value);
    }

    return _alwaysDestructive.contains(name);
  }

  Expression? _namedArgument(MethodInvocation node, String name) {
    for (final argument in node.argumentList.arguments) {
      if (argument is NamedExpression && argument.name.label.name == name) {
        return argument.expression;
      }
    }
    return null;
  }

  /// True when the outermost enclosing function body (method body, or the
  /// callback closure for code in a field initializer such as the
  /// GitCommands list) contains a `confirmDestructive` invocation.
  bool _enclosingScopeContainsGuard(MethodInvocation node) {
    FunctionBody? outermost;
    for (
      AstNode? current = node.parent;
      current != null;
      current = current.parent
    ) {
      if (current is FunctionBody) outermost = current;
    }
    if (outermost == null) return false;

    final finder = _GuardFinder();
    outermost.accept(finder);
    return finder.found;
  }

  /// Matches `// confirmed-by: <non-empty text>` in the comment lines directly
  /// above the statement containing the invocation.
  static final RegExp _marker = RegExp(r'^///?\s*confirmed-by:\s*\S');

  bool _hasConfirmedByMarker(MethodInvocation node) {
    final anchor = node.thisOrAncestorOfType<Statement>() ?? node;
    for (
      Token? comment = anchor.beginToken.precedingComments;
      comment != null;
      comment = comment.next
    ) {
      if (_marker.hasMatch(comment.lexeme)) return true;
    }
    return false;
  }
}

class _GuardFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'confirmDestructive') {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }
}

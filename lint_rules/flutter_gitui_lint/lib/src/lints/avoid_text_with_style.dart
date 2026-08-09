import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a hand-set `TextStyle` on `Text` — and, since #432, a hand-set style
/// whose `color:` restates the ambient foreground.
///
/// **The decision this rule enforces (#432): a `Text` call site never owns
/// the colour of a styled word.** The theme ramp does:
/// `AppTheme._brightnessCorrectedTextTheme` (lib/shared/theme/app_theme.dart)
/// applies the scheme's `onSurface` to every step of the type scale, so every
/// `textTheme.<role>` already carries the correct, brightness-aware
/// foreground. Where a word must *differ* from ambient, that difference is a
/// meaning — a `Tone` — and it reaches text through `BaseLabel(role:, tone:)`,
/// where the skin resolves what the meaning looks like. A `color:` inside a
/// hand-set style can therefore only do one of two wrong things: restate what
/// the ramp already says, or spell out a decision that belongs to the
/// vocabulary.
///
/// What the rule reports:
///
/// * A `style:` that is not a `copyWith` over a `textTheme` role — a
///   `TextStyle` literal, a computed style — **replaces** a role wholesale.
///   Use a `BaseLabel` subclass and state the meaning. (Unchanged since the
///   rule's first form.)
/// * A `copyWith` over a `textTheme` role whose `color:` ends in
///   `.onSurface` **restates** the ambient foreground. The argument paints
///   nothing — the ramp already carries that colour on every step — and it
///   keeps a `colorScheme` read alive in application code, which is exactly
///   the read the tone migration deletes. Delete the argument.
///
/// What the rule deliberately lets pass, and why:
///
/// * A `copyWith` over a `textTheme` role that names **no colour** adjusts
///   facets — weight, slant, family, leading — the contract vocabulary has
///   no word for yet, while inheriting the ramp's colour, which is correct
///   by construction. Each such site carries a comment naming its gap and
///   converts to `BaseLabel` when the word exists.
/// * A `copyWith` naming any **other** colour is a real recolour: a meaning
///   awaiting its `Tone`. It passes under protest, because forcing it
///   through `BaseLabel` today would drop the weight or slant set beside it
///   — an appearance change inside a rename, which this programme forbids.
///   Those sites are the tone backlog, not a licence.
///
/// History, because the inversion is the point. The rule's first form waved
/// a `Text` through as soon as its `copyWith` mentioned any non-null
/// `color:`. That question dates from before the ramp was
/// brightness-corrected, when the Google Fonts base theme hard-carried
/// light-mode `onSurface` (#1D1B20) into the dark scale and an *unstated*
/// colour genuinely meant an unreadable word — a missing colour was an
/// accident, and demanding one was a real guard. The correction then moved
/// into the ramp, the accident became impossible, and the exemption turned
/// exactly backwards: it *required* application code to restate a colour as
/// the price of a hand-set style, while the tone gate required the same read
/// gone — the #432 contradiction, live at
/// `lib/features/merge/conflict_resolution_screen.dart` until this form.
///
/// Scope stays the `Text` widget, as it always was. The `SelectableText`
/// sites (the blame and diff viewers, the bisect answer) carry the same
/// ownership decision in their own comments; widening the rule to them is
/// its own change with its own blast radius, not a side effect of this one.
///
/// The restatement half is scoped to the application's own `lib/` — the same
/// scoping, for the same reason, as `token_read_is_mechanical`: a skin is
/// exactly where a colour decision is allowed to live (`docs/SKIN-CONTRACT
/// .md` §3.6 scopes the whole design-system rule family to `lib/**`), so the
/// Material skin restating `onSurface` inside its own chrome is the skin
/// exercising its ownership, not the defect this rule reports. The first
/// armed run proved the need: unscoped, the check fired three times inside
/// `packages/gitui_skin_material/`, each at a site whose colour is the
/// skin's to state. The replacement half keeps its original scope — the
/// blueprint skin switches it off package-wide with its reason on record,
/// and the Material skin answers it per site.
///
/// Known evasion, accepted: a colour bound to a local first
/// (`final c = colorScheme.onSurface; … copyWith(color: c)`) is not
/// recognised as a restatement. A lint is a tripwire, not a proof — the
/// review question stays "who owns this colour", and the answer stays "not
/// this call site".
class AvoidTextWithStyle extends DartLintRule {
  const AvoidTextWithStyle() : super(code: _handSetStyle);

  static const _handSetStyle = LintCode(
    name: 'avoid_text_with_style',
    problemMessage:
        'Avoid using the Text widget with a custom TextStyle. Use a BaseLabel '
        'subclass (e.g., BodyMediumLabel, TitleLargeLabel, LabelSmallLabel) '
        'and state the meaning (role:, tone:) instead.',
  );

  /// Reported under the same rule name so one config entry governs both
  /// halves of the one decision: the application neither replaces a role nor
  /// restates the role's colour.
  static const _restatedAmbientColour = LintCode(
    name: 'avoid_text_with_style',
    problemMessage:
        'This copyWith restates the ambient foreground: every textTheme step '
        'already carries the scheme\'s onSurface '
        '(AppTheme._brightnessCorrectedTextTheme), so this color: argument '
        'paints nothing and keeps a colorScheme read alive in application '
        'code. Delete it. A colour that should DIFFER from ambient is a '
        'Tone, stated through BaseLabel(role:, tone:).',
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
      NamedExpression? styleArg;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'style') {
          styleArg = arg;
          break;
        }
      }

      if (styleArg == null) return;

      final Expression style = _unwrapParens(styleArg.expression);
      if (style is MethodInvocation &&
          style.methodName.name == 'copyWith' &&
          _adjustsAThemeRole(style)) {
        // An adjustment of a role rather than a replacement of one. The only
        // thing it may not do — in application code, where the ramp and the
        // Tone vocabulary own every foreground — is state the role's colour
        // back at it. A skin stating a colour is a skin doing its job.
        final NamedExpression? colorArg = _namedArgument(style, 'color');
        if (colorArg != null &&
            _isApplicationLibrary(resolver) &&
            _restatesAmbientForeground(colorArg.expression)) {
          reporter.atNode(colorArg, _restatedAmbientColour);
        }
        return;
      }

      reporter.atNode(node, _handSetStyle);
    });
  }

  /// The application package, whose `lib/` is where the colour-ownership
  /// decision binds.
  static const String _applicationPackage = 'flutter_gitui';

  /// True for a file in the application's own `lib/`. Mirrors
  /// `token_read_is_mechanical`'s scoping, including its reason for handling
  /// both URI forms: the URI arrives as `package:flutter_gitui/...` from the
  /// command line and as a `file:` path from the analysis server, and
  /// deciding on only one of them silently scopes nothing in the other.
  static bool _isApplicationLibrary(CustomLintResolver resolver) {
    final Uri uri = resolver.source.uri;
    if (uri.scheme == 'package') {
      return uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == _applicationPackage;
    }
    final String path = resolver.path.replaceAll(r'\', '/');
    if (path.contains('/test/') || path.contains('/packages/')) return false;
    return path.contains('/lib/');
  }

  /// True when [copyWith] is invoked on a chain that reads a `textTheme`
  /// role (`Theme.of(context).textTheme.bodyLarge?.copyWith(…)`,
  /// `theme.textTheme.labelSmall?.copyWith(…)`). A `copyWith` on anything
  /// else — a `TextStyle` literal, a passed-in style — is a replacement
  /// wearing an adjustment's syntax.
  static bool _adjustsAThemeRole(MethodInvocation copyWith) {
    AstNode? current = copyWith.target;
    while (current != null) {
      if (current is ParenthesizedExpression) {
        current = current.expression;
        continue;
      }
      if (current is PostfixExpression) {
        // The null-assert in `textTheme.bodyLarge!.copyWith(…)`.
        current = current.operand;
        continue;
      }
      if (current is PropertyAccess) {
        if (current.propertyName.name == 'textTheme') return true;
        current = current.target;
        continue;
      }
      if (current is PrefixedIdentifier) {
        return current.identifier.name == 'textTheme' ||
            current.prefix.name == 'textTheme';
      }
      if (current is MethodInvocation) {
        current = current.target;
        continue;
      }
      return false;
    }
    return false;
  }

  /// The named argument [name] of [invocation], or null.
  static NamedExpression? _namedArgument(
    MethodInvocation invocation,
    String name,
  ) {
    for (final arg in invocation.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) return arg;
    }
    return null;
  }

  /// True when [colorExpr] reads `….onSurface` — the one colour the ramp
  /// already applies to every step, making the argument a pure restatement.
  /// Any other expression (another scheme role, a derived colour, a
  /// conditional, a local) is a real recolour and is not this rule's to
  /// judge yet.
  static bool _restatesAmbientForeground(Expression colorExpr) {
    final Expression e = _unwrapParens(colorExpr);
    if (e is PropertyAccess) return e.propertyName.name == 'onSurface';
    if (e is PrefixedIdentifier) return e.identifier.name == 'onSurface';
    return false;
  }

  static Expression _unwrapParens(Expression e) {
    Expression current = e;
    while (current is ParenthesizedExpression) {
      current = current.expression;
    }
    return current;
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Classifies every `AppTheme.*` length read in the application's `lib/` as
/// either MECHANICAL — a codemod can move it without a human — or as a read a
/// human has to judge, and reports only the latter.
///
/// **This rule is a measuring instrument, not a ratchet, and it is deleted at
/// P6 of #249.** Say that here rather than in a commit message nobody reads
/// later: a migration lint that outlives its migration becomes noise nobody
/// dares remove, because nobody remembers what question it was answering. The
/// question is in `docs/SKIN-CONTRACT.md` §5.2, and it is the one that decides
/// whether detokenising this application (P3c) is a script or a year. When the
/// last `AppTheme.*` read is gone, the rule has answered it and this file goes
/// with it.
///
/// The classification is §5.2's, verbatim:
///
/// > A bare `AppTheme.*` token as a named argument in a closed set of positions
/// > (`SizedBox` `width:`/`height:`, an `EdgeInsets` argument, `Radius`/
/// > `BorderRadius`, `size:`, `spacing:`, `runSpacing:`, `iconSize:`) is
/// > MECHANICAL. A token inside a binary expression is DESIGN-BEARING.
///
/// Why those two halves partition the work: a bare token in one of those
/// positions is a 1:1 substitution — `SizedBox(height: AppTheme.paddingM)`
/// becomes `layout.gap(c, Proximity.related)` and `EdgeInsets.all(AppTheme
/// .paddingM)` becomes `layout.inset(c, child, all: Inset.normal)`, with the
/// rung read straight off the constant. A token inside arithmetic is the leak
/// the whole contract exists to stop: `AppTheme.iconXL * 2` and
/// `AppTheme.paddingL + AppTheme.paddingS` are the application deciding a
/// *length*, not naming a *relationship*, so there is no rung to read off and
/// no substitution to generate. Somebody has to choose a rung, or move the
/// measured layout into the skin where numbers are legal (§1, "the residue").
///
/// The question is asked of the CONSTRUCTION as well as of the token, and that
/// is a repair rather than an embellishment. Reading only the token's immediate
/// parent files `EdgeInsets.all(AppTheme.paddingM) * 2` as mechanical -
/// indistinguishable from `EdgeInsets.all(AppTheme.paddingM)` - and the codemod
/// is then authorised to rewrite it to `layout.inset(c, child, all:
/// Inset.normal)`, halving that padding with nobody in the loop. `lib/` happens
/// to contain no instance of the shape today, so the published partition below
/// is unchanged by the repair; what changes is that it stays true for code
/// written between now and P3c, which is the only thing a continuously
/// re-measured number is worth having.
///
/// It reports a third case §5.2 does not name, under its own message, because
/// the rule's own name is the claim being tested — *this token read is
/// mechanical* — and the absence of arithmetic does not establish that. A token
/// at `Container(width:)`, at `elevation:`, or at a `Base*` parameter of the
/// application's own invention is bare and yet sits in none of the seven
/// positions the codemod knows how to rewrite. Reporting those separately keeps
/// the headline number — the design-bearing reads — honest, and turns "the rest
/// is mechanical" from an assumption into a number.
///
/// The run, on `master` at 0.5.21-alpha and re-run after the construction
/// repair above with identical results, partitioned the **1,318**
/// `AppTheme.*` numeric reads the analyser resolves in `lib/` as
/// **1,230 mechanical : 49 design-bearing : 39 unplaced** — 93.3% a script can
/// move. §5.2 estimates "approximately 32 occurrences in 16 files" for the
/// design-bearing half; the real figures are 49 reads in 17 files, because 32
/// counts *lines* (33 distinct source lines carry the 49 reads) and 16 omits
/// `lib/shared/dialogs/branch_switcher_dialog.dart`. The 1,340 in §3.6 is a
/// text grep: it also counts 17 references to non-numeric members
/// (`AppTheme.lightTheme`, `AppTheme.availableFonts`, the animation getters)
/// and 5 mentions inside comments, and 1,340 − 22 = 1,318 reconciles exactly.
/// Rerun the rule rather than trusting this paragraph; that is what it is for.
///
/// **Off by default**, which is deliberate and is the reason it can ship
/// mid-migration at all. Every site it reports is legal code today; P3 has not
/// reached any of them. A rule that fires in CI would turn
/// `dart run custom_lint --fatal-infos --fatal-warnings` red on the very
/// codebase it is supposed to be measuring. Turn it on for a measurement with:
///
/// ```yaml
/// custom_lint:
///   rules:
///     - token_read_is_mechanical
/// ```
///
/// Scope is the application's own `lib/` — `package:flutter_gitui/**` — because
/// that is the population §5.2's numbers describe and the population P3c has to
/// edit. Test files are excluded (they assert behaviour, and T2 in §3.4 is the
/// instrument that judges them); skin packages are excluded because a skin is
/// exactly where a number is allowed to live.
class TokenReadIsMechanical extends DartLintRule {
  const TokenReadIsMechanical() : super(code: _designBearingCode);

  /// A migration classifier reports on code that is legal today, so it must not
  /// fire unless somebody asked it to. See the class doc for how to ask.
  @override
  bool get enabledByDefault => false;

  static const _designBearingCode = LintCode(
    name: 'token_read_is_mechanical',
    problemMessage:
        'DESIGN-BEARING token read: this AppTheme.* constant sits inside an '
        'arithmetic expression, so the application - not the skin - is '
        'deciding a length here. The P3c codemod has no 1:1 rewrite for it '
        '(SKIN-CONTRACT.md §5.2).',
    correctionMessage:
        'A human must pick the Proximity/Inset rung this expression really '
        'means, or move the measured layout into the skin, where numbers are '
        'legal (SKIN-CONTRACT.md §1, "the residue"). Migration-only rule: it '
        'is deleted at P6.',
  );

  /// Reported under the same rule name, so one config entry governs both and
  /// the two numbers stay countable side by side.
  static const _unplacedCode = LintCode(
    name: 'token_read_is_mechanical',
    problemMessage:
        'UNPLACED token read: this AppTheme.* constant is bare, but it is in '
        'none of the positions the P3c codemod knows how to rewrite (SizedBox '
        'width:/height:, an EdgeInsets/Radius/BorderRadius argument, size:, '
        'spacing:, runSpacing:, iconSize:), so "the rest is mechanical" does '
        'not cover it.',
    correctionMessage:
        'Either the position belongs in the codemod\'s closed set - add it '
        'there and to SKIN-CONTRACT.md §5.2 - or this read needs a human, like '
        'a design-bearing one. Migration-only rule: it is deleted at P6.',
  );

  /// The application package. Its `lib/` is the migration surface §5.2 counts.
  static const String _applicationPackage = 'flutter_gitui';

  /// The class whose static constants are the tokens under study.
  static const String _tokenHolder = 'AppTheme';

  /// Arithmetic on a token is what makes a read design-bearing. Comparison and
  /// logical operators are listed because a token used as a threshold
  /// (`width > AppTheme.paddingM`) is the same kind of application-side
  /// decision; none exist in `lib/` today, and if one appears it should be
  /// reported rather than silently counted as mechanical.
  static const Set<String> _binaryOperators = {
    '+',
    '-',
    '*',
    '/',
    '~/',
    '%',
    '<',
    '<=',
    '>',
    '>=',
  };

  /// Named arguments that are mechanical wherever they appear, per §5.2.
  static const Set<String> _mechanicalArgumentNames = {
    'size',
    'spacing',
    'runSpacing',
    'iconSize',
  };

  /// Named arguments that are mechanical only on a `SizedBox`, per §5.2. On
  /// anything else a width or a height is a measured box, not a gap.
  static const Set<String> _sizedBoxArgumentNames = {'width', 'height'};

  /// Types every argument of which is mechanical, because the whole
  /// construction is what `layout.inset` / the skin's shape resolver replaces.
  static const Set<String> _mechanicalOwnerTypes = {
    'EdgeInsets',
    'EdgeInsetsDirectional',
    'Radius',
    'BorderRadius',
    'BorderRadiusDirectional',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isApplicationLibrary(resolver)) return;

    context.registry.addPrefixedIdentifier((node) {
      if (node.prefix.name != _tokenHolder) return;
      _report(node, reporter);
    });

    context.registry.addPropertyAccess((node) {
      // Covers a token reached through an import prefix (`t.AppTheme.padding`),
      // which no file uses today but which would otherwise be invisible to the
      // census and so silently deflate the number.
      final Expression? target = node.target;
      final String? targetName = switch (target) {
        SimpleIdentifier(:final String name) => name,
        PrefixedIdentifier(identifier: SimpleIdentifier(:final String name)) =>
          name,
        _ => null,
      };
      if (targetName != _tokenHolder) return;
      _report(node, reporter);
    });
  }

  /// True for a file in the application's own `lib/`, which is the population
  /// §5.2's numbers describe and the population P3c has to edit.
  ///
  /// The URI arrives as `package:flutter_gitui/...` from the command line and
  /// as a `file:` path from the analysis server, so both forms are handled;
  /// deciding on only one of them silently measures nothing in the other, which
  /// is exactly how a classifier reports a reassuring zero.
  static bool _isApplicationLibrary(CustomLintResolver resolver) {
    final Uri uri = resolver.source.uri;
    if (uri.scheme == 'package') {
      return uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == _applicationPackage;
    }
    final String path = resolver.path.replaceAll(r'\', '/');
    // Test files assert behaviour; T2 (§3.4) is the instrument that judges
    // those. Workspace members under packages/ are skins, and a skin is exactly
    // where a number is allowed to live.
    if (path.contains('/test/') || path.contains('/packages/')) return false;
    return path.contains('/lib/');
  }

  void _report(Expression read, DiagnosticReporter reporter) {
    // Only the length constants are in scope. Resolving the static type rather
    // than matching member names keeps `AppTheme.availableFonts`,
    // `AppTheme.lightTheme` and the animation getters out of the census without
    // a hand-maintained exclusion list that would rot the moment a constant is
    // added.
    final type = read.staticType;
    if (type == null || !(type.isDartCoreDouble || type.isDartCoreInt)) return;

    switch (_classify(read)) {
      case _Placement.designBearing:
        reporter.atNode(read, _designBearingCode);
      case _Placement.unplaced:
        reporter.atNode(read, _unplacedCode);
      case _Placement.mechanical:
        break;
    }
  }

  _Placement _classify(Expression read) {
    // Parentheses are punctuation, not placement: `(AppTheme.paddingM) * 2` is
    // the same decision as `AppTheme.paddingM * 2`, and a parenthesised bare
    // token in `SizedBox(width:)` is still a bare token.
    Expression current = read;
    AstNode? parent = current.parent;
    while (parent is ParenthesizedExpression) {
      current = parent;
      parent = current.parent;
    }

    if (parent is BinaryExpression &&
        _binaryOperators.contains(parent.operator.lexeme)) {
      return _Placement.designBearing;
    }
    // Negating a token is arithmetic on it too. `Positioned(top: -AppTheme
    // .paddingS)` decides a length as surely as a multiplication does.
    if (parent is PrefixExpression &&
        (parent.operator.lexeme == '-' || parent.operator.lexeme == '+')) {
      return _Placement.designBearing;
    }

    if (parent is NamedExpression && parent.expression == current) {
      final String label = parent.name.label.name;
      final AstNode? arguments = parent.parent;
      if (arguments is! ArgumentList) return _Placement.unplaced;

      if (_mechanicalArgumentNames.contains(label)) {
        return _placementOfTheConstructionAround(arguments);
      }
      final String? owner = _ownerTypeName(arguments);
      if (_sizedBoxArgumentNames.contains(label) && owner == 'SizedBox') {
        return _placementOfTheConstructionAround(arguments);
      }
      if (owner != null && _mechanicalOwnerTypes.contains(owner)) {
        return _placementOfTheConstructionAround(arguments);
      }
      return _Placement.unplaced;
    }

    if (parent is ArgumentList) {
      final String? owner = _ownerTypeName(parent);
      if (owner != null && _mechanicalOwnerTypes.contains(owner)) {
        return _placementOfTheConstructionAround(parent);
      }
      return _Placement.unplaced;
    }

    return _Placement.unplaced;
  }

  /// Asks the same question of the CONSTRUCTION the token sits in that
  /// [_classify] asked of the token itself, and returns
  /// [_Placement.mechanical] only if the construction is left alone too.
  ///
  /// Without this the rule reads one level and stops, so
  /// `EdgeInsets.all(AppTheme.paddingM) * 2` files as MECHANICAL - identical
  /// to `EdgeInsets.all(AppTheme.paddingM)` - and the P3c codemod is then
  /// authorised to rewrite it to `layout.inset(c, child, all: Inset.normal)`,
  /// silently halving that padding with no human in the loop and no diagnostic
  /// anywhere saying a length changed. The same hole swallows
  /// `+ EdgeInsets.all(4)` and `.copyWith(top: 0)`.
  ///
  /// The two answers differ deliberately. Arithmetic on the construction is
  /// the application deciding a length, exactly as arithmetic on the token is,
  /// so it is DESIGN-BEARING. A method or a cascade applied to it -
  /// `.copyWith`, `.resolve`, `.add` - is not arithmetic, but it is equally
  /// not a 1:1 substitution the codemod can generate, so it is UNPLACED: the
  /// bucket that exists precisely for a bare token in a position the script
  /// has no rewrite for.
  static _Placement _placementOfTheConstructionAround(ArgumentList arguments) {
    final AstNode? construction = arguments.parent;
    if (construction is! Expression) return _Placement.mechanical;

    Expression current = construction;
    AstNode? parent = current.parent;
    while (parent is ParenthesizedExpression) {
      current = parent;
      parent = current.parent;
    }

    if (parent is BinaryExpression &&
        _binaryOperators.contains(parent.operator.lexeme)) {
      return _Placement.designBearing;
    }
    if (parent is PrefixExpression &&
        (parent.operator.lexeme == '-' || parent.operator.lexeme == '+')) {
      return _Placement.designBearing;
    }
    // `EdgeInsets.all(t).copyWith(...)`, `BorderRadius.circular(t).topLeft`,
    // and the cascade form of either. The construction is the target rather
    // than the whole expression, which is what distinguishes it from an
    // ordinary argument position.
    if (parent is MethodInvocation && parent.target == current) {
      return _Placement.unplaced;
    }
    if (parent is PropertyAccess && parent.target == current) {
      return _Placement.unplaced;
    }
    if (parent is CascadeExpression && parent.target == current) {
      return _Placement.unplaced;
    }
    return _Placement.mechanical;
  }

  /// The name of the type being constructed around [arguments], or null when
  /// the argument list belongs to something that is not a construction.
  static String? _ownerTypeName(ArgumentList arguments) {
    final AstNode? owner = arguments.parent;
    if (owner is InstanceCreationExpression) {
      return owner.staticType?.element?.name;
    }
    return null;
  }
}

/// Where one token read sits, and therefore who has to move it.
enum _Placement {
  /// Inside arithmetic: a length the application decided. A human moves it.
  designBearing,

  /// A bare token in one of §5.2's seven positions: a script moves it.
  mechanical,

  /// A bare token somewhere the codemod has no rewrite for. Also a human.
  unplaced,
}

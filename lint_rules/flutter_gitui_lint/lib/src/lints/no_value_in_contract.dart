import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces the spine rule of the skin contract (#249): **no member of
/// `packages/gitui_skin_api` names a design VALUE.**
///
/// > No member of the skin contract returns or carries a `Color`, a length, an
/// > `EdgeInsets`, a `TextStyle`, a `ShapeBorder`, a `Duration` or an
/// > `IconData`. Every member returns a `Widget` or a `Route`.
/// > — `docs/SKIN-CONTRACT.md` §0
///
/// **Why a lint and not the import ban.** The contract package imports
/// `package:flutter/widgets.dart` and nothing else from Flutter, and until this
/// rule existed that fact was doing duty as the proof of the spine rule. It
/// cannot carry that claim, and the gap was measured rather than suspected: the
/// resolved export namespace of `package:flutter/widgets.dart` contains
/// `Color` (through `dart:ui`), `EdgeInsets`, `EdgeInsetsGeometry`,
/// `TextStyle`, `ShapeBorder`, `IconData`, `BoxDecoration`, `BorderRadius`,
/// `BoxShadow`, `Gradient`, `Curve`, `Curves` and the entire `WidgetState`
/// family, and `Duration` is `dart:core`. Adding `final Color tint;` to a spec
/// therefore changes no import: `flutter analyze` stays green, the
/// workspace-isolation gate stays green (it scans directives), and the
/// blueprint keeps compiling, because a new spec FIELD obliges a skin to
/// implement nothing. A design value would have crossed the contract with
/// every stated guard green.
///
/// What the import ban does prove is the other half, and it keeps proving it: a
/// Material-*named* type - `ThemeData`, `ThemeExtension`, `InputBorder`,
/// `ButtonStyle`, `PopupMenuEntry`, `Icons`, `Colors` - does not resolve here
/// at all. The two guards are complementary and neither replaces the other.
///
/// **How it fires.** On the resolved type of every type annotation written in
/// the package, so an alias, a `typedef`, a generic argument
/// (`ValueChanged<Color>`, `List<TextStyle>`) and a `dart:ui` import prefix are
/// all caught by the same test. Comments are invisible to it by construction:
/// it walks the AST, and the doc comments in this contract discuss `Color` and
/// `Duration` at length precisely because those are the things it may not name.
///
/// **The three declared latitudes** (`docs/SKIN-CONTRACT.md` §2.9) are not
/// exempted here, because none of them names a banned type:
/// `localizationsDelegates` and `scrollBehavior` are behaviour objects and
/// `windowChrome` is an enum. The one value-shaped thing the contract does
/// carry is `double`, and it is handled by [_kSanctionedDoubles] below rather
/// than by a blanket exemption.
class NoValueInContract extends DartLintRule {
  const NoValueInContract() : super(code: _valueCode);

  static const _valueCode = LintCode(
    name: 'no_value_in_contract',
    problemMessage:
        'The skin contract may not name a design value. This type is one of '
        'the values the spine rule bans (SKIN-CONTRACT.md §0): a member that '
        'carries it hands the application a number, a colour or a style to '
        'hold, and every leak detector in §3 draws its sharpness from there '
        'being nothing to hold.',
    correctionMessage:
        'State the QUESTION instead of the answer: Tone rather than Color, '
        'Proximity/Inset rather than a length or an EdgeInsets, TextRole '
        'rather than a TextStyle, IconRole rather than an IconData, '
        'MotionRole rather than a Duration, Elevation rather than a shadow. '
        'If the vocabulary genuinely has no rung for it, the member is '
        'missing, not the value.',
  );

  /// Reported for a `double` that is not in the sanctioned list. A separate
  /// message because a `double` is not automatically a length - a fraction, a
  /// scale and a screen coordinate are all legitimate - and the point is to
  /// make each one a decision somebody wrote down.
  static const _doubleCode = LintCode(
    name: 'no_value_in_contract',
    problemMessage:
        'An unsanctioned `double` in the skin contract. A length is the one '
        'design value that wears no special type, so every double here has to '
        'be named in the sanctioned list with the reason it is not a length '
        '(lint_rules/flutter_gitui_lint/lib/src/lints/no_value_in_contract.dart).',
    correctionMessage:
        'If it is a fraction, a scale or a coordinate the application already '
        'owns, add it to the list with that reason. If it is a length, it '
        'belongs to the skin: use Proximity, Inset or ControlScale.',
  );

  /// The package this rule guards. The blueprint and the shipping skins are
  /// deliberately not in scope - a skin is exactly where a number is allowed
  /// to live.
  static const String _contractPackage = 'gitui_skin_api';

  /// The values the spine rule bans by name.
  ///
  /// Every entry is nameable from `package:flutter/widgets.dart` or
  /// `dart:core`, which is the whole reason this rule exists. The
  /// Material-named types (`ThemeData`, `InputBorder`, `ButtonStyle`, …) are
  /// deliberately absent: they cannot resolve in this package at all, and
  /// listing them here would suggest the import ban were not doing that job.
  static const Set<String> _bannedTypes = {
    // Colour, in every shape it reaches this package in.
    'Color', 'ColorSwatch', 'HSLColor', 'HSVColor', 'Gradient',
    // Length and geometry the skin owns.
    'EdgeInsets', 'EdgeInsetsGeometry', 'EdgeInsetsDirectional',
    'BorderRadius', 'BorderRadiusGeometry', 'Radius',
    'Border', 'BorderSide', 'BoxBorder', 'ShapeBorder', 'OutlinedBorder',
    'BoxDecoration', 'Decoration', 'ShapeDecoration', 'BoxShadow', 'Shadow',
    // Type.
    'TextStyle', 'StrutStyle', 'TextHeightBehavior', 'FontWeight',
    // Time and easing.
    'Duration', 'Curve', 'Curves', 'Tween', 'Animation',
    // Iconography.
    'IconData', 'IconThemeData',
    // The state-dependent value family, which is a resolver for all of the
    // above and is exported from widgets.dart in full.
    'WidgetState', 'WidgetStateProperty', 'WidgetStateColor',
    'WidgetStatePropertyAll', 'WidgetStatesController',
    'WidgetStateTextStyle', 'WidgetStateBorderSide',
    'WidgetStateOutlinedBorder', 'WidgetStateMouseCursor',
  };

  /// Every `double` the contract is allowed to carry, and why it is not a
  /// length. The list may shrink; an addition is a design decision that has to
  /// be argued here, next to the rule it weakens.
  ///
  /// Keyed by the declared name alone rather than by class, because these
  /// names are distinctive and a key that carried a class would rot the first
  /// time a spec was renamed.
  static const Map<String, String> _kSanctionedDoubles = {
    // The user's own accessibility choices, carried to the skin to resolve.
    // A multiplier is not a length: it has no unit until a skin gives it one.
    'textScale': "the user's text-size preference, a multiplier",
    'animationScale': "the user's motion preference, a multiplier",
    // How far along something is, from 0 to 1. Unitless by definition, and the
    // application is the only thing that knows it.
    'fraction': 'progress or a split, from 0 to 1 - unitless',
    // A split's stored position, which is user state and crosses the seam the
    // same way a selected index does.
    'onFractionChanged': 'reports the split fraction back, still unitless',
    // A slider's value domain is the application's: a byte count, a percentage,
    // a number of days. None of it is a screen length.
    'value': "a slider's value, in the application's own units",
    'min': "a slider's lower bound, in the application's own units",
    'max': "a slider's upper bound, in the application's own units",
    'onChanged': "a slider's value, reported back in the same units",
    'onChangeEnd': "a slider's value once the user lets go, same units",
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isContractLibrary(resolver)) return;

    context.registry.addNamedType((NamedType node) {
      final DartType? type = node.type;
      final String name = type?.element?.name ?? node.name.lexeme;

      if (_bannedTypes.contains(name)) {
        reporter.atNode(node, _valueCode);
        return;
      }
      if (name != 'double') return;
      if (_isSanctionedDouble(node)) return;
      reporter.atNode(node, _doubleCode);
    });
  }

  /// True for a library inside the contract package.
  ///
  /// The URI arrives as `package:gitui_skin_api/...` from the analysis server
  /// and as a `file:` path from the command-line runner, so both forms are
  /// handled. Deciding on only one of them would make the rule silently
  /// measure nothing in the other - which for a guard is worse than not having
  /// it, because the green run reads as a proof.
  static bool _isContractLibrary(CustomLintResolver resolver) {
    final Uri uri = resolver.source.uri;
    if (uri.scheme == 'package') {
      return uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == _contractPackage;
    }
    final String path = resolver.path.replaceAll(r'\', '/');
    return path.contains('/packages/$_contractPackage/lib/');
  }

  /// Whether this `double` is one the contract is allowed to carry.
  ///
  /// The declared name is taken from whatever declaration encloses the
  /// annotation - a field, a parameter, a getter - so `double fraction`,
  /// `required double fraction` and `ValueChanged<double>? onFractionChanged`
  /// all resolve to the same key.
  static bool _isSanctionedDouble(NamedType node) {
    for (AstNode? at = node; at != null; at = at.parent) {
      final String? name = switch (at) {
        VariableDeclarationList(variables: final List<VariableDeclaration> v)
            when v.isNotEmpty =>
          v.first.name.lexeme,
        // FunctionTypedFormalParameter is a FormalParameter too, so a
        // `void Function(double) onChanged` parameter resolves here as well.
        FormalParameter(name: final Token? token) => token?.lexeme,
        MethodDeclaration(name: final Token token) => token.lexeme,
        _ => null,
      };
      if (name != null) return _kSanctionedDoubles.containsKey(name);
    }
    return false;
  }
}

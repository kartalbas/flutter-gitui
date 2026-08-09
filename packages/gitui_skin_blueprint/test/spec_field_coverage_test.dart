/// The blueprint's obligation, executed - for every facet, not for one.
///
/// `docs/SKIN-CONTRACT-MEMBERS.md` §9 states the obligation and the rule that
/// makes it checkable:
///
/// > a blueprint member that does not read one of its spec's fields is a build
/// > failure, enforced by a test that reflects over each spec class and asserts
/// > every field is referenced in the corresponding blueprint member.
///
/// `dart:mirrors` does not exist on the Flutter platform, so the reflection is
/// done over the CONTRACT'S OWN SOURCE instead - which is stronger in the one
/// way that matters here, because a field added to a spec appears in the
/// source the moment it is written, whether or not anything has been compiled
/// against it yet.
///
/// Two properties were missing when this covered `SkinControls` alone, and
/// each of them let a real field ship dropped:
///
///  * **It covered one facet of seven.** `AppIdentity.appIcon` was accepted by
///    `chrome.shell` and never drawn, never marked and never carried to the
///    debug surface, and nothing reddened. Every spec class in the contract is
///    now mapped to the facets allowed to read it, and the completeness test
///    below fails the run for any spec class that is in the contract and
///    absent from the map - so the next spec cannot be added without deciding
///    who reads it - and for any name in the map that has left the contract,
///    so the register cannot rot either.
///  * **A mention satisfied it.** The matcher ran over raw source, and
///    `appIcon` appears in a doc comment explaining why it was not drawn, so
///    extending the old test as it stood would have gone green on a field that
///    is only ever discussed. [_withoutCommentsOrStringText] now removes both
///    comments and the literal text of strings before anything is matched -
///    the second half measured rather than assumed, because the repaired
///    facet's own allowlist string `'chrome.shell/appIcon'` re-satisfied the
///    matcher on its own and kept the test green with the `Image` deleted.
///
/// The check is deliberately coarse: it asserts that the field's NAME occurs in
/// the facet's code. It cannot prove the field is rendered correctly, and it
/// does not try to. What it makes impossible is the failure §9 is actually
/// about - a parameter nobody thought about, silently accepted and silently
/// dropped, teaching the next skin author that dropping it is normal.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where the contract's spec classes are written.
const String _chromeSpecs = '../gitui_skin_api/lib/src/specs/chrome_specs.dart';
const String _controlSpecs =
    '../gitui_skin_api/lib/src/specs/control_specs.dart';
const String _fieldSpec = '../gitui_skin_api/lib/src/specs/field_spec.dart';
const String _layoutSpecs = '../gitui_skin_api/lib/src/specs/layout_specs.dart';
const String _overlaySpecs =
    '../gitui_skin_api/lib/src/specs/overlay_specs.dart';
const String _surfaceSpecs =
    '../gitui_skin_api/lib/src/specs/surface_specs.dart';
const String _toolbarSpecs =
    '../gitui_skin_api/lib/src/specs/toolbar_specs.dart';
const String _typeSpecs = '../gitui_skin_api/lib/src/specs/type_specs.dart';

/// Every spec source the completeness check reads.
const List<String> _allSpecSources = <String>[
  _chromeSpecs,
  _controlSpecs,
  _fieldSpec,
  _layoutSpecs,
  _overlaySpecs,
  _surfaceSpecs,
  _toolbarSpecs,
  _typeSpecs,
];

/// Where the blueprint's facets are written.
const String _chrome = 'lib/src/facets/blueprint_chrome.dart';
const String _controls = 'lib/src/facets/blueprint_controls.dart';
const String _layout = 'lib/src/facets/blueprint_layout.dart';
const String _motion = 'lib/src/facets/blueprint_motion.dart';
const String _overlays = 'lib/src/facets/blueprint_overlays.dart';
const String _surfaces = 'lib/src/facets/blueprint_surfaces.dart';
const String _type = 'lib/src/facets/blueprint_type.dart';

/// Not a facet, but the skin's own root: `SkinRootClaims` is answered by the
/// skin rather than rendered by a facet, and the three declared latitudes are
/// exactly the members it answers.
const String _skin = 'lib/src/blueprint_skin.dart';

/// One spec class, where it is declared, and which facets may read it.
///
/// Several specs are legitimately read by more than one facet - a toolbar
/// entry appears in the shell, on a screen and in a panel header - so a field
/// has to be read by at least ONE of the listed facets rather than by all of
/// them. Listing them explicitly is what makes the map a decision rather than
/// a search: adding a spec means saying who renders it.
class _Coverage {
  const _Coverage(this.source, this.facets);

  final String source;
  final List<String> facets;
}

const Map<String, _Coverage> _specs = <String, _Coverage>{
  // chrome
  'SkinRequest': _Coverage(_chromeSpecs, <String>[_chrome]),
  'SkinRootClaims': _Coverage(_chromeSpecs, <String>[_skin]),
  'AppIdentity': _Coverage(_chromeSpecs, <String>[_chrome]),
  'ShellDestination': _Coverage(_chromeSpecs, <String>[_chrome]),
  'ShellAside': _Coverage(_chromeSpecs, <String>[_chrome]),
  'ShellStatus': _Coverage(_chromeSpecs, <String>[_chrome]),
  'ActivitySpec': _Coverage(_chromeSpecs, <String>[_chrome]),
  'BlockingProgressSpec': _Coverage(_chromeSpecs, <String>[_chrome]),
  'ShellSpec': _Coverage(_chromeSpecs, <String>[_chrome]),
  'SelectionBarSpec': _Coverage(_chromeSpecs, <String>[_chrome]),
  'ScreenSpec': _Coverage(_chromeSpecs, <String>[_chrome]),
  'DialogAction': _Coverage(_chromeSpecs, <String>[_chrome]),
  'DialogSpec': _Coverage(_chromeSpecs, <String>[_chrome, _overlays]),
  // controls
  'ButtonSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'IconButtonSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'ToggleSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'ToggleRowSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'SliderSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'DateFieldSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'SuggestItem': _Coverage(_controlSpecs, <String>[_controls]),
  'SuggestFieldSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'DropdownOption': _Coverage(_controlSpecs, <String>[_controls]),
  'DropdownSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'ChoiceOption': _Coverage(_controlSpecs, <String>[_controls]),
  'ChoiceGroupSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'FilterToggleSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'SeriesPickerSpec': _Coverage(_controlSpecs, <String>[_controls]),
  'FieldSpec': _Coverage(_fieldSpec, <String>[_controls]),
  'FieldHandles': _Coverage(_fieldSpec, <String>[_controls]),
  'FieldActionAffordance': _Coverage(_fieldSpec, <String>[_controls]),
  // layout
  'GridSpec': _Coverage(_layoutSpecs, <String>[_layout]),
  'SplitPaneSpec': _Coverage(_layoutSpecs, <String>[_layout]),
  'PropertyRow': _Coverage(_layoutSpecs, <String>[_layout]),
  'PropertyListSpec': _Coverage(_layoutSpecs, <String>[_layout]),
  // overlays
  'MenuSection': _Coverage(_overlaySpecs, <String>[_overlays]),
  'MenuAction': _Coverage(_overlaySpecs, <String>[_overlays]),
  'MenuCheckable': _Coverage(_overlaySpecs, <String>[_overlays]),
  'MenuChoice': _Coverage(_overlaySpecs, <String>[_overlays]),
  'MenuAnchorSpec': _Coverage(_overlaySpecs, <String>[_overlays]),
  'NoticeAction': _Coverage(_overlaySpecs, <String>[_overlays]),
  'NoticeSpec': _Coverage(_overlaySpecs, <String>[_overlays]),
  'PopoverSpec': _Coverage(_overlaySpecs, <String>[_overlays]),
  // surfaces
  'CardSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'PanelSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'DisclosureSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'ListRowSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'TreeNodeSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'TreeSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'TabEntry': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'TabSetSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'DataGridSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'PressableSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'BadgeFact': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'BadgeSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'TagSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'AvatarSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'BannerSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'EmptyStateAction': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'EmptyStateSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'DropTargetSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'CodeLineSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'CodeBlockSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'GraphEdgeSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'GraphRowSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'GraphGutterSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'MarkdownSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  'ImageViewerSpec': _Coverage(_surfaceSpecs, <String>[_surfaces]),
  // toolbar
  'ToolbarActionEntry': _Coverage(_toolbarSpecs, <String>[_chrome, _surfaces]),
  'ToolbarPickerEntry': _Coverage(_toolbarSpecs, <String>[_chrome]),
  'ToolbarMenuEntry': _Coverage(_toolbarSpecs, <String>[_chrome]),
  'ToolbarGroup': _Coverage(_toolbarSpecs, <String>[_chrome]),
  // type
  'TextRun': _Coverage(_typeSpecs, <String>[_type, _surfaces]),
};

/// Spec classes the map deliberately does not cover, each with its reason.
///
/// Only two kinds of thing belong here: a class with no fields at all (there is
/// nothing to drop), and a class the CONTRACT package renders itself, where a
/// skin never sees the fields in the first place.
const Map<String, String> _notASpec = <String, String>{
  'MenuSeparator':
      'carries no fields at all - a separator is its own whole meaning',
  'ToolbarSeparatorEntry': 'the same, on a toolbar',
  'FieldClearAffordance': 'a sealed marker with no fields',
  'FieldRevealAffordance': 'a sealed marker with no fields',
  'NoticeHandle':
      'an interface the SKIN implements rather than a spec it reads; its '
      'members are what the application may do to a live notice',
  'SkinFormFieldHost':
      'a widget the contract package builds itself, so that form registration '
      'cannot be forgotten by a skin - no skin ever reads its fields',
  'FieldAffordance':
      'the sealed base of the three in-field affordances; the cases carry the '
      'meaning and the base carries nothing',
  'MenuEntry': 'the sealed base of the four menu entries, with no fields',
  'ToolbarEntry': 'the sealed base of the four toolbar entries, with no fields',
};

/// The one field of every mapped class that a facet legitimately never reads,
/// and the reason.
///
/// `SkinFormFieldHost` consumes the validator before the skin is called -
/// which is the entire point of the host existing, because `macos_ui` ships no
/// `FormField` at all and a skin that had to remember to register its own
/// field is a skin that will forget. The blueprint renders the merged `error`
/// the host hands back instead.
const Map<String, String> _consumedElsewhere = <String, String>{
  'FieldSpec.validator':
      'consumed by SkinFormFieldHost in the contract package, which registers '
      'every field with the enclosing Form exactly once so that no skin has '
      'to remember to',
  'DialogSpec.onSubmit':
      "consumed by the application's own DialogKeyboardHost, which sits "
      "BETWEEN the skin's route and the skin's surface: Enter-submits is "
      'what the user can do, so no skin may weaken it and no skin is asked '
      'to implement it',
};

void main() {
  final Map<String, String> facetSource = <String, String>{
    for (final String path in <String>[
      _chrome,
      _controls,
      _layout,
      _motion,
      _overlays,
      _surfaces,
      _type,
      _skin,
    ])
      path: _withoutCommentsOrStringText(File(path).readAsStringSync()),
  };

  test('every spec class in the contract is mapped to a facet', () {
    final Set<String> declared = <String>{
      for (final String path in _allSpecSources)
        ..._classesIn(File(path).readAsStringSync()),
    };
    final Set<String> unmapped = declared
        .where(
          (String name) =>
              !_specs.containsKey(name) && !_notASpec.containsKey(name),
        )
        .toSet();

    expect(
      unmapped,
      isEmpty,
      reason:
          'These spec classes are in the contract and in neither table below. '
          'A spec nobody is recorded as reading is exactly how '
          'AppIdentity.appIcon shipped dropped: add each to _specs with the '
          'facets that render it, or to _notASpec with the reason it has '
          'nothing for a skin to drop.',
    );

    final Set<String> stale = <String>{
      ..._specs.keys,
      ..._notASpec.keys,
    }.where((String name) => !declared.contains(name)).toSet();
    expect(
      stale,
      isEmpty,
      reason:
          'These names are in the tables but no longer in the contract. A '
          'register that keeps rows for things that no longer exist stops '
          'being read.',
    );
  });

  group('the blueprint accepts every parameter of every spec', () {
    for (final MapEntry<String, _Coverage> entry in _specs.entries) {
      test('${entry.key} is read in full', () {
        final List<String> fields = _fieldsOf(
          File(entry.value.source).readAsStringSync(),
          entry.key,
        );
        expect(
          fields,
          isNotEmpty,
          reason:
              'No fields were found on ${entry.key}. Either the class was '
              'renamed or this test stopped being able to read the contract, '
              'and an obligation nobody can measure is not an obligation.',
        );
        for (final String field in fields) {
          final String qualified = '${entry.key}.$field';
          if (_consumedElsewhere.containsKey(qualified)) continue;
          final bool read = entry.value.facets.any(
            (String facet) =>
                RegExp('\\b$field\\b').hasMatch(facetSource[facet]!),
          );
          expect(
            read,
            isTrue,
            reason:
                '$qualified is never read in ${entry.value.facets.join(' or ')}'
                ' - and comments do not count, because this matcher strips '
                'them. The blueprint implements every member and accepts every '
                'parameter (docs/SKIN-CONTRACT-MEMBERS.md §9): render it '
                'distinguishably, or - if a naked square genuinely cannot show '
                'it without becoming design - record it in _consumedElsewhere '
                'with the reason, which is a decision somebody reviews rather '
                'than a silence nobody sees.',
          );
        }
      });
    }
  });
}

/// The declared fields of one class in one contract source file.
///
/// The contract is `dart format`ted, so a class body runs from its header to
/// the first `}` in column zero, and every field is a `final` declaration at
/// one level of indentation. Anything cleverer would be a Dart parser, and a
/// Dart parser is not what makes this check trustworthy - reading the same
/// file the contract is written in is.
List<String> _fieldsOf(String source, String className) {
  final int start = source.indexOf(RegExp('class $className[ <{]'));
  if (start < 0) return const <String>[];
  final int end = source.indexOf(RegExp(r'^\}', multiLine: true), start);
  final String body = source.substring(start, end < 0 ? source.length : end);
  return RegExp(r'^  final [^;]+?([A-Za-z_][A-Za-z0-9_]*);', multiLine: true)
      .allMatches(body)
      .map((RegExpMatch match) => match.group(1)!)
      .toList(growable: false);
}

/// Every public class declared in one contract source file.
///
/// Private classes are skipped: a `_ControllerBridge` inside the form-field
/// host is an implementation detail of the contract package, not a seam a skin
/// ever sees.
List<String> _classesIn(String source) =>
    RegExp(
          r'^(?:final |abstract interface |sealed )?class ([A-Za-z][A-Za-z0-9_]*)',
          multiLine: true,
        )
        .allMatches(source)
        .map((RegExpMatch match) => match.group(1)!)
        .toList(growable: false);

/// Reduces a facet to the code that could actually READ a field: comments and
/// the literal text of strings are removed, and only the interpolations inside
/// a string survive.
///
/// Both removals are load-bearing, and each was measured rather than guessed.
///
///  * **Comments.** `AppIdentity.appIcon` appeared exactly once in the whole
///    package, inside a doc comment explaining why the raster was not drawn -
///    so a matcher over raw source went green on a field that was only ever
///    mentioned. That is the failure the coverage test exists to prevent,
///    passing the coverage test.
///  * **String literals.** The repair to that field names its own allowlist
///    entry, `'chrome.shell/appIcon'`, and that string alone re-satisfied the
///    matcher: deleting the `Image` widget beside it left the test green. A
///    name inside a string is never a read.
///
/// Interpolations are kept because they ARE reads: `'(${blocking.currentStep})'`
/// is the only place some fields are touched, and dropping them would turn
/// this check from too weak into too strict.
///
/// Block comments are replaced by an equal number of newlines so that anything
/// reported by line number still points at the source's own line.
String _withoutCommentsOrStringText(String source) => source
    .replaceAllMapped(
      RegExp(r'/\*.*?\*/', dotAll: true),
      (Match m) => '\n' * '\n'.allMatches(m.group(0)!).length,
    )
    .split('\n')
    .map(_withoutLineComment)
    .map(_withoutStringText)
    .join('\n');

/// One line, without its trailing `//` comment.
String _withoutLineComment(String line) {
  final int at = line.indexOf('//');
  if (at < 0) return line;
  // A `//` inside a string literal is not a comment. The only strings in
  // these facets that contain one would be URLs, and there are none; the
  // cheap check keeps that assumption visible rather than silent.
  final String before = line.substring(0, at);
  final int quotes = "'".allMatches(before).length;
  return quotes.isEven ? before : line;
}

/// One line, with each string literal reduced to its interpolations.
String _withoutStringText(String line) => line.replaceAllMapped(
  RegExp('\'(?:[^\'\\\\\n]|\\\\.)*\'|"(?:[^"\\\\\n]|\\\\.)*"'),
  (Match match) => RegExp(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*')
      .allMatches(match.group(0)!)
      .map((RegExpMatch interpolation) => interpolation.group(0)!)
      .join(' '),
);

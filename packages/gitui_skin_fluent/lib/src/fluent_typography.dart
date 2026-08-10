/// The type facet's numbers: the Windows 11 type ramp, the mapping of the
/// application's nine [TextRole]s onto it, and the one door that resolves a
/// role against the user's request.
///
/// Nothing here is invented. Every metric carries where it came from - the
/// published Windows / WinUI specification or the reference checkout at
/// `D:/repos/github/fluent_ui` (read, never compiled or shipped) - the same
/// provenance discipline the conformance deviation register uses. The two
/// sources used throughout, cited short as SPEC and XAML-RAMP:
///
///  * SPEC - "Typography in Windows",
///    https://learn.microsoft.com/en-us/windows/apps/design/signature-experiences/typography
///  * XAML-RAMP - "XAML theme resources", section "The XAML type ramp",
///    https://learn.microsoft.com/en-us/windows/apps/develop/platform/xaml/xaml-theme-resources
library;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fluent_request_scope.dart';

/// The Windows 11 type ramp, stated once.
///
/// Eight steps - 68 / 40 / 28 / 20 / 18 / 14 / 14 / 12 - with the size,
/// line height and weight pairs published in SPEC ("Type ramp" table) and
/// XAML-RAMP, and implemented identically in the reference at
/// `fluent_ui/lib/src/styles/typography.dart:112-168`. The published ramp
/// also names a ninth step, Body Large Strong (18px Semibold,
/// `BodyLargeStrongTextBlockStyle` in XAML-RAMP), which the reference does
/// not carry; it is not declared here because no member reaches for it - the
/// day one does, it is added with this provenance rather than guessed.
///
/// **Family.** Every step names `Segoe UI Variable` with `Segoe UI` behind
/// it. SPEC: "Segoe UI Variable is the new system font for Windows", and the
/// XAML base text style pins `FontFamily="Segoe UI Variable"` (XAML-RAMP,
/// `BaseRichTextBlockStyle` definition). The reference deliberately sets no
/// family and inherits the platform default (`typography.dart` builds every
/// `TextStyle` without one); that is not carried, because this application
/// also ships to Linux, where the platform default is not Segoe - naming the
/// family keeps Windows exact and lets the engine fall through to its default
/// sans elsewhere.
///
/// **Weight.** Regular is w400 and Semibold is w600, per SPEC's "Weights"
/// table (Light 300, Semilight 350, Regular 400, Semibold 600, Bold 700).
/// SPEC's best-practice table: "Use regular weight for most text, use
/// Semibold for titles".
///
/// **Height** is the published line height expressed as the ratio Flutter
/// wants, written as the fraction itself (`92 / 68`) so the two published
/// numbers stay visible - the reference writes them the same way
/// (`typography.dart:115`).
///
/// **No colour.** The reference stamps `textFillColorPrimary` onto every
/// step (`fluent_ui/lib/src/styles/theme.dart:464-467`); this ramp
/// deliberately does not. Text follows the surface it sits on - the
/// correction the Material skin carries at
/// `material_type.dart` (a stamped foreground paints the unselected role
/// straight over a selected container) - so which colour a line takes is the
/// colour side's answer, resolved where the surface is known.
abstract final class FluentTypeRamp {
  /// SPEC: "Segoe UI Variable is the new system font for Windows".
  static const String _family = 'Segoe UI Variable';

  /// The pre-Windows-11 face behind it, for hosts without the variable font.
  /// SPEC lists it among the sans-serif UI fonts; the engine falls through
  /// further on its own where neither exists (Linux).
  static const List<String> _familyFallback = <String>['Segoe UI'];

  /// Display: 68/92, Semibold. SPEC type-ramp table; reference
  /// `typography.dart:113-118`.
  static const TextStyle display = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _familyFallback,
    fontSize: 68,
    height: 92 / 68,
    fontWeight: FontWeight.w600,
  );

  /// Title Large: 40/52, Semibold. SPEC type-ramp table; reference
  /// `typography.dart:120-125`.
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _familyFallback,
    fontSize: 40,
    height: 52 / 40,
    fontWeight: FontWeight.w600,
  );

  /// Title: 28/36, Semibold. SPEC type-ramp table; reference
  /// `typography.dart:127-132`.
  static const TextStyle title = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _familyFallback,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w600,
  );

  /// Subtitle: 20/28, Semibold. SPEC type-ramp table; reference
  /// `typography.dart:134-139`.
  static const TextStyle subtitle = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _familyFallback,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
  );

  /// Body Large: 18/24, Regular. SPEC type-ramp table; reference
  /// `typography.dart:141-146`.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _familyFallback,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w400,
  );

  /// Body Strong: 14/20, Semibold. SPEC type-ramp table; reference
  /// `typography.dart:148-153`.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _familyFallback,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  /// Body: 14/20, Regular. SPEC type-ramp table; reference
  /// `typography.dart:155-160`.
  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _familyFallback,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Caption: 12/16, **Regular**. SPEC type-ramp table and XAML-RAMP
  /// ("Caption | Regular | 12"); SPEC's legibility floor is explicit:
  /// "Minimum values: 14px Semibold, 12px Regular - text smaller than these
  /// sizes and weights are illegible in some languages".
  ///
  /// The reference's CODE sets w300 here (`typography.dart:166`), which
  /// contradicts the reference's own doc table two hundred lines up
  /// ("caption | 12px | 16px | Regular", `typography.dart:21`) and would sit
  /// below the published floor. The specification wins; the w300 is judged a
  /// reference bug and not carried.
  static const TextStyle caption = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _familyFallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );
}

/// How this skin turns the nine application text roles into the Windows 11
/// ramp.
///
/// The ramp is [FluentTypeRamp]'s and is settled; THIS table is the
/// judgement, stated once so that the one place a role changes appearance is
/// a line in this file - the same arrangement as `MaterialTypeScale`
/// (`gitui_skin_material/lib/src/material_ink.dart:390`).
///
/// Fluent's answer is deliberately quieter than Material's: the nine jobs
/// land on four rungs. `sectionTitle` and `emphasis` share Body Strong,
/// `itemTitle`, `body` and `control` share Body, and `detail` and `micro`
/// share Caption. Each collapse is the language's own statement, documented
/// at its arm below and pinned by test so it can only ever change as a
/// decision - hierarchy in Fluent comes from placement and from the
/// secondary text colour, not from a size step per job. The upper rungs
/// (Display, Title Large, Title, Body Large) are not reached from here at
/// all: the reference spends Title on window-scale chrome - `PageHeader`
/// (`controls/layout/page.dart:279`) and the `ContentDialog` title
/// (`flyouts/content_dialog.dart:508`) - which arrives through
/// `ScreenSpec.title` and `DialogSpec.title` and is the chrome and overlay
/// members' to draw in that idiom.
///
/// **This is the ramp mapping only, and a facet must not call it directly.**
/// It is pure and cannot reach the user's [SkinRequest], so it cannot answer
/// the families the user chooses or the text scale. `FluentTypeResolution`
/// is the single door - the exact split `MaterialTypeResolution` records
/// (`material_theme.dart:659`), kept because the two halves of
/// `TextRole.code` once disagreed inside the Material skin when a surface
/// bypassed the door.
abstract final class FluentTypeScale {
  /// The ramp step [role] lands on. Pure: same answer for every context.
  static TextStyle stepOf(TextRole role) => switch (role) {
    // The loudest line in a REGION - and four of five uses are the headline
    // of an empty or error state in the middle of a panel
    // (`gitui_skin_api/lib/src/vocabulary.dart`, TextRole.pageTitle). The
    // region-scale heading of the ramp is Subtitle, "Display semibold
    // 20/28" (SPEC type-ramp table). Title (28) is NOT the answer here:
    // the reference spends it on window-scale chrome (`PageHeader`,
    // `controls/layout/page.dart:279`; `ContentDialog` title,
    // `flyouts/content_dialog.dart:508`), and stamping chrome treatment on
    // every empty state is the substitution failure this role's own doc
    // warns against.
    TextRole.pageTitle => FluentTypeRamp.subtitle,

    // The name of a region inside a screen. Fluent titles at text size in
    // Semibold: the NavigationView pane's own section header renders
    // bodyStrong (`navigation/navigation_view/theme.dart:184`,
    // `itemHeaderTextStyle`), as does the InfoBar title
    // (`surfaces/info_bar.dart:380`). SPEC: "use Semibold for titles", and
    // 14px is the smallest Semibold the floor allows. Body Large was
    // considered and rejected - 18 Regular does not do the header job in a
    // language whose titles are Semibold - and Subtitle would make a
    // panel's section outshout the panel.
    TextRole.sectionTitle => FluentTypeRamp.bodyStrong,

    // The name of one object. Fluent names objects in Regular body and
    // drops the SECONDARY line to caption in the secondary colour - the
    // reference's ListTile title is typography.body
    // (`surfaces/list_tile.dart:305`). This is the language speaking:
    // Material answers the same role with a Semibold-ish titleSmall
    // (`material_ink.dart:397`), Fluent builds the hierarchy from colour,
    // not weight.
    TextRole.itemTitle => FluentTypeRamp.body,

    // "Use this for the majority of text" (reference `typography.dart:71`;
    // SPEC type-ramp table).
    TextRole.body => FluentTypeRamp.body,

    // Prose that must stand out from the prose beside it. THE
    // weight-at-the-same-size distinction Fluent draws that Material draws
    // differently - and the contract holds: the role states prominence,
    // and this language answers it with Body Strong. SPEC, verbatim: "Use
    // Semibold instead of Bold for emphasis"; reference
    // `typography.dart:66` ("Use for labels or emphasized text").
    TextRole.emphasis => FluentTypeRamp.bodyStrong,

    // Supporting detail. Caption is "the smallest text style for
    // supplementary information" (reference `typography.dart:74-78`), and
    // the reference's ListTile subtitle renders it
    // (`surfaces/list_tile.dart:311`).
    TextRole.detail => FluentTypeRamp.caption,

    // Badge counts, chip labels, status pills. Caption is the ramp's
    // FLOOR: SPEC's minimum is "12px Regular - text smaller than these
    // sizes and weights are illegible in some languages", so the ramp
    // cannot answer "smaller than detail" without inventing. WinUI's own
    // badge digits are 11px (reference `utils/info_badge.dart:119`, the
    // `InfoBadgeValueFontSize` resource) - considered and rejected: it is
    // a control's private metric for numerals with no published line
    // height, and micro also carries words. The collapse with [detail] is
    // reported in the mapping doc above, not hidden.
    TextRole.micro => FluentTypeRamp.caption,

    // Text the user operates. Fluent operates its controls in Regular
    // body: the Button label is typography.body (reference
    // `buttons/base.dart:178`), as are the TextBox
    // (`form/text_box.dart:1310`) and ComboBox (`form/combo_box.dart:1276`).
    // No emboldening - where Material gives controls labelLarge at w500,
    // a Fluent button label IS body text. That collapse is the language's
    // own statement.
    TextRole.control => FluentTypeRamp.body,

    // Monospaced by definition - alignment is meaning. The METRICS are
    // Body's (the reading step code lines sit in; the ramp has no mono
    // step of its own), and the FAMILY is the user's, applied only by
    // [FluentTypeResolution] from `SkinRequest.monoFamily`. The family
    // named here is the floor for a tree with no request in it: Consolas
    // is the fixed-width face SPEC's font table publishes for Windows
    // ("Fixed width font that supports European scripts"), with the
    // engine's own monospace behind it - so even an unresolved code line
    // keeps its columns, which is more than a proportional fallback would
    // honour.
    TextRole.code => _code,
  };

  /// Body's metrics with the published fixed-width floor. See the
  /// [TextRole.code] arm for why the primary family is not Segoe.
  static const TextStyle _code = TextStyle(
    fontFamily: 'Consolas',
    fontFamilyFallback: <String>['monospace'],
    fontSize: 14, // Body: SPEC type-ramp table, 14/20 Regular.
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
}

/// The one door a facet uses to turn a [TextRole] into a style.
///
/// [FluentTypeScale] states the ramp mapping and nothing else; this adds
/// what only the tree can know - the user's request. Four of its fields
/// land here:
///
///  * `monoFamily` - the family for [TextRole.code], the user's own choice
///    carried across the contract as a name;
///  * `codeScale` - the size half of that same choice: it multiplies INTO
///    the scale [TextRole.code] is resolved at (`textScale * codeScale`,
///    rounded once to a whole pixel), because the contract states it as a
///    refinement on top of the interface preference. Every other role
///    ignores it;
///  * `uiFamily` - the interface family for every other role. Honoured, not
///    overridden: the contract calls it "the interface family the user
///    chose", and a skin that ignored a stated choice would fail the
///    Substitution Test from the other side. When the user's family cannot
///    be resolved, the fallback is this LANGUAGE's own face (Segoe on the
///    ramp step, Consolas on code) rather than another skin's default - the
///    same forgiveness `MaterialTypeResolution.styleOf` extends
///    (`material_theme.dart:672-679`), landing on Fluent's floor instead of
///    Material's;
///  * `textScale` - multiplied into the step's size and rounded to a whole
///    pixel, exactly the arithmetic the Material skin applies to the same
///    user setting (`material_theme.dart:429`,
///    `(size * scale).roundToDouble()`), so one preference means one thing
///    across skins. The height rides along unchanged because the ramp
///    states it as a ratio.
///
/// It is a single door on purpose: the Material skin once answered
/// `TextRole.code` with the user's monospace family in the type facet and
/// with the proportional interface family in the code surfaces, because a
/// surface called the ramp directly (`material_theme.dart:650-658`). Every
/// Fluent facet resolves through here, and nothing else calls
/// [FluentTypeScale].
abstract final class FluentTypeResolution {
  /// The style [role] takes under the request in force at [context].
  ///
  /// Outside a `FluentRequestScope` - only a test rendering a facet without
  /// its root - the bare ramp step answers, at scale 1.0 in the language's
  /// own families.
  static TextStyle styleOf(BuildContext context, TextRole role) {
    final TextStyle step = FluentTypeScale.stepOf(role);
    final SkinRequest? request = FluentRequestScope.maybeOf(context);
    if (request == null) return step;
    return _resolve(
      step,
      scale: role == TextRole.code
          ? request.textScale * request.codeScale
          : request.textScale,
      family: role == TextRole.code ? request.monoFamily : request.uiFamily,
    );
  }

  /// The style a CHROME ramp step takes under the request in force at
  /// [context] - the door for the upper rungs no [TextRole] reaches.
  ///
  /// The mapping doc on [FluentTypeScale] records that the reference spends
  /// Title on window-scale chrome (`PageHeader`, `controls/layout/
  /// page.dart:279`; the `ContentDialog` title, `flyouts/
  /// content_dialog.dart:508`), which arrives through `ScreenSpec.title` and
  /// `DialogSpec.title` rather than through a role. The chrome facet still
  /// owes those lines the user's interface family and text scale, and it
  /// owes them through THIS file: a second copy of the family-and-scale
  /// arithmetic in the chrome would be exactly the drift the single door
  /// exists to prevent. [step] is one of [FluentTypeRamp]'s members; the
  /// resolution is the interface half of [styleOf]'s (never the monospace
  /// half, because no chrome line is code).
  static TextStyle chromeStyleOf(BuildContext context, TextStyle step) {
    final SkinRequest? request = FluentRequestScope.maybeOf(context);
    if (request == null) return step;
    return _resolve(step, scale: request.textScale, family: request.uiFamily);
  }

  /// [step] under the user's [scale] and [family] - the one place the two
  /// halves of the request become a style.
  static TextStyle _resolve(
    TextStyle step, {
    required double scale,
    required String family,
  }) {
    final TextStyle scaled = _scaled(step, scale);
    if (family.isEmpty) return scaled;
    try {
      return GoogleFonts.getFont(family, textStyle: scaled);
    } catch (_) {
      // An unknown family keeps the language's own face rather than failing
      // the build - the forgiveness described in the class doc.
      return scaled;
    }
  }

  /// [step] at the user's text scale: size multiplied and rounded to a
  /// whole pixel (`material_theme.dart:429` arithmetic, see class doc).
  static TextStyle _scaled(TextStyle step, double scale) => scale == 1.0
      ? step
      : step.copyWith(fontSize: (step.fontSize! * scale).roundToDouble());
}

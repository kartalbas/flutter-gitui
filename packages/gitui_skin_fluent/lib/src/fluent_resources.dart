import 'dart:ui';

/// The slice of the WinUI resource dictionary this skin has needed so far.
///
/// Fluent 2 names its colours as *resources* (`ControlFillColorDefault`,
/// `TextFillColorPrimary`, ...) and every control state maps onto a resource
/// rather than onto an ad-hoc colour. This class carries that vocabulary, and
/// it grows a field only when a control needs one - a resource nobody reads is
/// a guess about the future.
///
/// Every value is read out of the reference checkout, never invented:
/// fluent_ui@4.16.1 `lib/src/styles/color_resources.dart` declares the WinUI
/// resource dictionary verbatim (`ResourceDictionary.light` at :276,
/// `ResourceDictionary.dark` at :189), which itself transcribes
/// microsoft-ui-xaml `dev/CommonStyles/Common_themeresources_any.xaml`. Each
/// field cites both constructors' lines beside its values.
final class FluentResources {
  const FluentResources({
    required this.textFillColorPrimary,
    required this.textFillColorSecondary,
    required this.textFillColorDisabled,
    required this.textOnAccentFillColorPrimary,
    required this.textOnAccentFillColorSecondary,
    required this.textOnAccentFillColorDisabled,
    required this.accentTextFillColorDisabled,
    required this.controlFillColorDefault,
    required this.controlFillColorSecondary,
    required this.controlFillColorTertiary,
    required this.controlFillColorDisabled,
    required this.controlFillColorTransparent,
    required this.subtleFillColorTransparent,
    required this.subtleFillColorSecondary,
    required this.subtleFillColorTertiary,
    required this.subtleFillColorDisabled,
    required this.accentFillColorDisabled,
    required this.controlStrokeColorDefault,
    required this.controlStrokeColorSecondary,
    required this.controlStrokeColorOnAccentDefault,
    required this.controlStrokeColorOnAccentSecondary,
    required this.focusStrokeColorOuter,
    required this.focusStrokeColorInner,
    required this.solidBackgroundFillColorBase,
    required this.solidBackgroundFillColorSecondary,
    required this.solidBackgroundFillColorTertiary,
    required this.solidBackgroundFillColorQuarternary,
    required this.cardBackgroundFillColorDefault,
    required this.cardStrokeColorDefault,
    required this.surfaceStrokeColorFlyout,
    required this.systemFillColorSuccess,
    required this.systemFillColorCaution,
    required this.systemFillColorCritical,
  });

  /// WinUI light theme.
  ///
  /// Sources: fluent_ui@4.16.1 lib/src/styles/color_resources.dart, the
  /// `ResourceDictionary.light` constructor (:276-345); resource names from
  /// microsoft-ui-xaml Common_themeresources_any.xaml.
  const FluentResources.light()
    : // TextFillColorPrimary, color_resources.dart:277.
      textFillColorPrimary = const Color(0xe4000000),
      // TextFillColorSecondary, color_resources.dart:278.
      textFillColorSecondary = const Color(0x9e000000),
      // TextFillColorDisabled, color_resources.dart:280.
      textFillColorDisabled = const Color(0x5c000000),
      // TextOnAccentFillColorPrimary, color_resources.dart:284.
      textOnAccentFillColorPrimary = const Color(0xFFffffff),
      // TextOnAccentFillColorSecondary, color_resources.dart:285.
      textOnAccentFillColorSecondary = const Color(0xb3ffffff),
      // TextOnAccentFillColorDisabled, color_resources.dart:286. Deliberately
      // NOT dimmed in light: the dimming lives in AccentFillColorDisabled.
      textOnAccentFillColorDisabled = const Color(0xFFffffff),
      // AccentTextFillColorDisabled, color_resources.dart:282.
      accentTextFillColorDisabled = const Color(0x5c000000),
      // ControlFillColorDefault, color_resources.dart:287.
      controlFillColorDefault = const Color(0xb3ffffff),
      // ControlFillColorSecondary (hover), color_resources.dart:288.
      controlFillColorSecondary = const Color(0x80f9f9f9),
      // ControlFillColorTertiary (pressed), color_resources.dart:289.
      controlFillColorTertiary = const Color(0x4df9f9f9),
      // ControlFillColorDisabled, color_resources.dart:291.
      controlFillColorDisabled = const Color(0x4df9f9f9),
      // ControlFillColorTransparent, color_resources.dart:292.
      controlFillColorTransparent = const Color(0x00ffffff),
      // SubtleFillColorTransparent, color_resources.dart:297.
      subtleFillColorTransparent = const Color(0x00ffffff),
      // SubtleFillColorSecondary (hover), color_resources.dart:298.
      subtleFillColorSecondary = const Color(0x09000000),
      // SubtleFillColorTertiary (pressed), color_resources.dart:299.
      subtleFillColorTertiary = const Color(0x06000000),
      // SubtleFillColorDisabled, color_resources.dart:300.
      subtleFillColorDisabled = const Color(0x00ffffff),
      // AccentFillColorDisabled, color_resources.dart:310.
      accentFillColorDisabled = const Color(0x37000000),
      // ControlStrokeColorDefault, color_resources.dart:311.
      controlStrokeColorDefault = const Color(0x0f000000),
      // ControlStrokeColorSecondary (the darker bottom of the elevation
      // stroke), color_resources.dart:312.
      controlStrokeColorSecondary = const Color(0x29000000),
      // ControlStrokeColorOnAccentDefault, color_resources.dart:313.
      controlStrokeColorOnAccentDefault = const Color(0x14ffffff),
      // ControlStrokeColorOnAccentSecondary, color_resources.dart:314.
      controlStrokeColorOnAccentSecondary = const Color(0x66000000),
      // FocusStrokeColorOuter: near-black on the light ground,
      // color_resources.dart:326.
      focusStrokeColorOuter = const Color(0xe4000000),
      // FocusStrokeColorInner: white against the outer stroke,
      // color_resources.dart:327.
      focusStrokeColorInner = const Color(0xb3ffffff),
      // SolidBackgroundFillColorBase - the page ground translucent fills
      // composite against, color_resources.dart:340.
      solidBackgroundFillColorBase = const Color(0xFFf3f3f3),
      // SolidBackgroundFillColorSecondary, color_resources.dart:341.
      solidBackgroundFillColorSecondary = const Color(0xFFeeeeee),
      // SolidBackgroundFillColorTertiary, color_resources.dart:342.
      solidBackgroundFillColorTertiary = const Color(0xFFf9f9f9),
      // SolidBackgroundFillColorQuarternary, color_resources.dart:343.
      solidBackgroundFillColorQuarternary = const Color(0xFFffffff),
      // CardBackgroundFillColorDefault, color_resources.dart:328.
      cardBackgroundFillColorDefault = const Color(0xb3ffffff),
      // CardStrokeColorDefault, color_resources.dart:318.
      cardStrokeColorDefault = const Color(0x0f000000),
      // SurfaceStrokeColorFlyout, color_resources.dart:323.
      surfaceStrokeColorFlyout = const Color(0x0f000000),
      // SystemFillColorSuccess, color_resources.dart:348.
      systemFillColorSuccess = const Color(0xFF0f7b0f),
      // SystemFillColorCaution, color_resources.dart:349.
      systemFillColorCaution = const Color(0xFF9d5d00),
      // SystemFillColorCritical, color_resources.dart:350.
      systemFillColorCritical = const Color(0xFFc42b1c);

  /// WinUI dark theme.
  ///
  /// Sources: fluent_ui@4.16.1 lib/src/styles/color_resources.dart, the
  /// `ResourceDictionary.dark` constructor (:189-258); resource names from
  /// microsoft-ui-xaml Common_themeresources_any.xaml.
  const FluentResources.dark()
    : // TextFillColorPrimary, color_resources.dart:190.
      textFillColorPrimary = const Color(0xFFffffff),
      // TextFillColorSecondary, color_resources.dart:191.
      textFillColorSecondary = const Color(0xc5ffffff),
      // TextFillColorDisabled, color_resources.dart:193.
      textFillColorDisabled = const Color(0x5dffffff),
      // TextOnAccentFillColorPrimary, color_resources.dart:197.
      textOnAccentFillColorPrimary = const Color(0xFF000000),
      // TextOnAccentFillColorSecondary, color_resources.dart:198.
      textOnAccentFillColorSecondary = const Color(0x80000000),
      // TextOnAccentFillColorDisabled - dark DOES dim the on-accent
      // foreground where light does not, color_resources.dart:199.
      textOnAccentFillColorDisabled = const Color(0x87ffffff),
      // AccentTextFillColorDisabled, color_resources.dart:195.
      accentTextFillColorDisabled = const Color(0x5dffffff),
      // ControlFillColorDefault, color_resources.dart:200.
      controlFillColorDefault = const Color(0x0fffffff),
      // ControlFillColorSecondary (hover), color_resources.dart:201.
      controlFillColorSecondary = const Color(0x15ffffff),
      // ControlFillColorTertiary (pressed), color_resources.dart:202.
      controlFillColorTertiary = const Color(0x08ffffff),
      // ControlFillColorDisabled, color_resources.dart:204.
      controlFillColorDisabled = const Color(0x0bffffff),
      // ControlFillColorTransparent, color_resources.dart:205.
      controlFillColorTransparent = const Color(0x00ffffff),
      // SubtleFillColorTransparent, color_resources.dart:210.
      subtleFillColorTransparent = const Color(0x00ffffff),
      // SubtleFillColorSecondary (hover), color_resources.dart:211.
      subtleFillColorSecondary = const Color(0x0fffffff),
      // SubtleFillColorTertiary (pressed), color_resources.dart:212.
      subtleFillColorTertiary = const Color(0x0affffff),
      // SubtleFillColorDisabled, color_resources.dart:213.
      subtleFillColorDisabled = const Color(0x00ffffff),
      // AccentFillColorDisabled, color_resources.dart:223.
      accentFillColorDisabled = const Color(0x28ffffff),
      // ControlStrokeColorDefault, color_resources.dart:224.
      controlStrokeColorDefault = const Color(0x12ffffff),
      // ControlStrokeColorSecondary, color_resources.dart:225.
      controlStrokeColorSecondary = const Color(0x18ffffff),
      // ControlStrokeColorOnAccentDefault, color_resources.dart:226.
      controlStrokeColorOnAccentDefault = const Color(0x14ffffff),
      // ControlStrokeColorOnAccentSecondary, color_resources.dart:227.
      controlStrokeColorOnAccentSecondary = const Color(0x23000000),
      // FocusStrokeColorOuter: white on the dark ground,
      // color_resources.dart:239.
      focusStrokeColorOuter = const Color(0xFFffffff),
      // FocusStrokeColorInner: near-black against the outer stroke,
      // color_resources.dart:240.
      focusStrokeColorInner = const Color(0xb3000000),
      // SolidBackgroundFillColorBase, color_resources.dart:253.
      solidBackgroundFillColorBase = const Color(0xFF202020),
      // SolidBackgroundFillColorSecondary, color_resources.dart:254.
      solidBackgroundFillColorSecondary = const Color(0xFF1c1c1c),
      // SolidBackgroundFillColorTertiary, color_resources.dart:255.
      solidBackgroundFillColorTertiary = const Color(0xFF282828),
      // SolidBackgroundFillColorQuarternary, color_resources.dart:256.
      solidBackgroundFillColorQuarternary = const Color(0xFF2c2c2c),
      // CardBackgroundFillColorDefault, color_resources.dart:241.
      cardBackgroundFillColorDefault = const Color(0x0dffffff),
      // CardStrokeColorDefault, color_resources.dart:231.
      cardStrokeColorDefault = const Color(0x19000000),
      // SurfaceStrokeColorFlyout, color_resources.dart:236.
      surfaceStrokeColorFlyout = const Color(0x33000000),
      // SystemFillColorSuccess, color_resources.dart:261.
      systemFillColorSuccess = const Color(0xFF6ccb5f),
      // SystemFillColorCaution, color_resources.dart:262.
      systemFillColorCaution = const Color(0xFFfce100),
      // SystemFillColorCritical, color_resources.dart:263.
      systemFillColorCritical = const Color(0xFFff99a4);

  /// Ordinary text.
  final Color textFillColorPrimary;

  /// Text one step quieter than [textFillColorPrimary]; WinUI presses a
  /// standard button's label into this while the pointer is down.
  final Color textFillColorSecondary;

  /// Text on a disabled control.
  final Color textFillColorDisabled;

  /// Text over the accent fill.
  final Color textOnAccentFillColorPrimary;

  /// Text over the accent fill while pressed.
  final Color textOnAccentFillColorSecondary;

  /// Text over a disabled accent fill.
  final Color textOnAccentFillColorDisabled;

  /// Accent-coloured text (a hyperlink) when disabled.
  final Color accentTextFillColorDisabled;

  /// A standard control's resting fill.
  final Color controlFillColorDefault;

  /// A standard control's hover fill.
  final Color controlFillColorSecondary;

  /// A standard control's pressed fill.
  final Color controlFillColorTertiary;

  /// A standard control's disabled fill.
  final Color controlFillColorDisabled;

  /// The explicit "no fill" a pressed accent border falls back to.
  final Color controlFillColorTransparent;

  /// A subtle (borderless) control's resting fill: nothing.
  final Color subtleFillColorTransparent;

  /// A subtle control's hover fill.
  final Color subtleFillColorSecondary;

  /// A subtle control's pressed fill.
  final Color subtleFillColorTertiary;

  /// A subtle control's disabled fill: still nothing.
  final Color subtleFillColorDisabled;

  /// The accent fill when the control is disabled.
  final Color accentFillColorDisabled;

  /// The main run of a standard control's outline.
  final Color controlStrokeColorDefault;

  /// The darker bottom edge of a standard control's elevation stroke.
  final Color controlStrokeColorSecondary;

  /// The main run of an accent control's outline.
  final Color controlStrokeColorOnAccentDefault;

  /// The darker bottom edge of an accent control's elevation stroke.
  final Color controlStrokeColorOnAccentSecondary;

  /// The outer of the two focus-rectangle strokes: dark on light grounds,
  /// light on dark grounds.
  final Color focusStrokeColorOuter;

  /// The inner focus stroke, always on the opposite side of the ledger from
  /// [focusStrokeColorOuter] - the pairing is what keeps the rectangle
  /// legible over any fill.
  final Color focusStrokeColorInner;

  /// The page ground. Every translucent control fill above composites
  /// against this, which is why state directions can only be measured over
  /// it.
  final Color solidBackgroundFillColorBase;

  /// The alternate ground, one step darker than the page.
  final Color solidBackgroundFillColorSecondary;

  /// The ground of a content layer sitting on the page.
  final Color solidBackgroundFillColorTertiary;

  /// The most raised solid ground: a popup's opaque stand-in.
  final Color solidBackgroundFillColorQuarternary;

  /// A resting card's fill; translucent, composited over the page ground
  /// (fluent_ui@4.16.1 lib/src/controls/surfaces/card.dart:107-112).
  final Color cardBackgroundFillColorDefault;

  /// The 1px stroke every card carries (card.dart:110-112).
  final Color cardStrokeColorDefault;

  /// The 1px stroke around a flyout or menu surface
  /// (fluent_ui@4.16.1 lib/src/controls/flyouts/flyout_content.dart:74).
  final Color surfaceStrokeColorFlyout;

  /// This finished, and it finished well; the InfoBar success foreground
  /// (fluent_ui@4.16.1 lib/src/controls/surfaces/info_bar.dart:623).
  final Color systemFillColorSuccess;

  /// This may not be what the user intended; the InfoBar warning foreground
  /// (info_bar.dart:621).
  final Color systemFillColorCaution;

  /// Destruction and failure; the InfoBar error foreground
  /// (info_bar.dart:625). WinUI has no attention FOREGROUND to sit beside
  /// these three - the informational icon is painted with the accent brush
  /// (info_bar.dart:619-620) - which is why `Tone.info` collapses onto the
  /// accent in `FluentInk`.
  final Color systemFillColorCritical;
}

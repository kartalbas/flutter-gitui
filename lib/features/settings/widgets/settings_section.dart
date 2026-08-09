import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_label.dart';

/// Base widget for settings sections with collapsible functionality
class SettingsSection extends StatefulWidget {
  final String title;

  /// The mark that names this section, as a MEANING rather than a glyph
  /// (#249, conflict C3): the eight sections say which idea labels them, and
  /// the active skin decides which mark stands for that idea.
  final IconRole icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  late bool _isExpanded;
  static const String _prefsKeyPrefix = 'settings_section_expanded_';

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _loadExpandedState();
  }

  Future<void> _loadExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKeyPrefix + _getSectionKey();
    final savedState = prefs.getBool(key);

    if (savedState != null && savedState != _isExpanded && mounted) {
      setState(() => _isExpanded = savedState);
    }
  }

  Future<void> _saveExpandedState(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKeyPrefix + _getSectionKey();
    await prefs.setBool(key, expanded);
  }

  String _getSectionKey() {
    // Use title as a simple key for storing state
    return widget.title.replaceAll(' ', '_').toLowerCase();
  }

  void _setExpanded(bool expanded) {
    setState(() => _isExpanded = expanded);
    _saveExpandedState(expanded);
  }

  /// A settings section is the first example `surfaces.disclosure` names in
  /// its own doc, and it now says itself that way: the press target, the
  /// header's inset, the naming mark, the caret and its half-turn, and the
  /// reveal of the body are all the member's. What left with them is
  /// everything this widget used to hand-build around them — the [InkWell]
  /// and the top-corner radius that shaped its ripple, the
  /// [AnimationController] and its [RotationTransition], and the
  /// [AnimatedCrossFade] whose curve and duration the member already carries.
  /// Which section is open stays APPLICATION state, because it is persisted
  /// per section and a rebuild must not lose it.
  ///
  /// Three things about the picture moved with the conversion, and each is
  /// named rather than implied. The 1 px `outlineVariant` rule the card drew
  /// under its header slot is GONE: the disclosure rides in the card's
  /// *content* slot now, and the member draws no line between header and
  /// body - M3's `ExpansionTile` separates the two by state, not by a rule.
  /// The caret is tinted `primary` while the section is open and muted while
  /// shut - `ExpansionTile`'s own open-state tint, pinned with its state by
  /// test/features/icon_conversion_pixel_identity_test.dart. And the member
  /// keeps an 8 dp gap between the title and its caret that the hand-built
  /// row never had, so a truncating title gives up those pixels.
  ///
  /// The card around it keeps its `Inset.none`: the sections' rows own their
  /// own edges, and the disclosure fills the card the way the command log's
  /// entries already do.
  @override
  Widget build(BuildContext context) {
    return BaseCard(
      inset: Inset.none,
      content: SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.surfaces.disclosure(
          inner,
          DisclosureSpec(
            // The mark that names the section is the disclosure's own
            // `leading` rather than something composed into the header port:
            // it names the whole revealed region, which is exactly the slot's
            // meaning, and the member draws it at the same 24 dp accent this
            // header always drew.
            leading: widget.icon,
            header: ContentPort(
              BaseLabel(widget.title, role: TextRole.sectionTitle),
            ),
            body: ContentPort(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
            expanded: _isExpanded,
            onExpandedChanged: _setExpanded,
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_card.dart';

/// Base widget for settings sections with collapsible functionality
class SettingsSection extends StatefulWidget {
  final String title;
  final IconData icon;
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

class _SettingsSectionState extends State<SettingsSection> with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _iconRotation;
  static const String _prefsKeyPrefix = 'settings_section_expanded_';

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _loadExpandedState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _iconRotation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKeyPrefix + _getSectionKey();
    final savedState = prefs.getBool(key);

    if (savedState != null && savedState != _isExpanded) {
      setState(() {
        _isExpanded = savedState;
        if (_isExpanded) {
          _animationController.value = 1.0;
        } else {
          _animationController.value = 0.0;
        }
      });
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

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
      _saveExpandedState(_isExpanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: EdgeInsets.zero,
      header: InkWell(
        onTap: _toggleExpanded,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: AppTheme.iconL,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.paddingM),
              Expanded(child: TitleLargeLabel(widget.title)),
              RotationTransition(
                turns: _iconRotation,
                child: Icon(
                  PhosphorIconsRegular.caretDown,
                  size: AppTheme.iconM,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      content: AnimatedCrossFade(
        firstChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.children,
        ),
        secondChild: const SizedBox.shrink(),
        crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 200),
      ),
    );
  }
}

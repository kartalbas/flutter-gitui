import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Proximity, TextRole;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../shared/components/base_badge.dart';
import '../../shared/components/base_dialog.dart';
import '../../shared/components/base_label.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/services/version_service.dart';
import '../../core/services/build_info.dart';
import '../../shared/components/base_layout.dart';

class AppAboutDialog extends HookConsumerWidget {
  const AppAboutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionService = ref.watch(versionServiceProvider);
    final version = useState<String>('...');

    useEffect(() {
      versionService.getCurrentVersion().then((v) {
        // The dialog can be closed before the version resolves; the hook
        // notifier is disposed with it and must not be written afterwards
        if (context.mounted) version.value = v;
      });
      return null;
    }, []);

    return BaseDialog(
      title: 'About Flutter GitUI',
      icon: IconRole.info,
      variant: DialogVariant.normal,
      onSubmit: () => Navigator.of(context).pop(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App icon and name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    ),
                    child: Icon(
                      Icons.commit,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const BaseGap(Proximity.grouped),
                  BaseLabel('Flutter GitUI', role: TextRole.pageTitle),
                  const BaseGap(Proximity.hairline),
                  BaseLabel('Version ${version.value}', role: TextRole.detail),
                  const BaseGap(Proximity.hairline),
                  BaseLabel(
                    'Build: ${BuildInfo.displayCommit}',
                    role: TextRole.detail,
                    align: TextAlign.center,
                  ),
                  if (BuildInfo.displayDate.isNotEmpty) ...[
                    const BaseGap(Proximity.hairline),
                    BaseLabel(
                      BuildInfo.displayDate,
                      role: TextRole.detail,
                      align: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const BaseGap(Proximity.separate),

            // Description
            Center(
              child: BaseLabel(
                'A cross-platform Git UI built with Flutter.',
                role: TextRole.body,
                align: TextAlign.center,
              ),
            ),

            const BaseGap(Proximity.separate),

            const Divider(),
            const BaseGap(Proximity.grouped),

            // Technology stack
            Center(child: BaseLabel('Built with', role: TextRole.sectionTitle)),
            const BaseGap(Proximity.related),
            Center(
              child: Wrap(
                spacing: AppTheme.paddingS,
                runSpacing: AppTheme.paddingS,
                children: [
                  _TechChip(label: 'Flutter', icon: Icons.flutter_dash),
                  _TechChip(label: 'Dart', icon: Icons.code),
                  _TechChip(label: 'Riverpod', icon: Icons.architecture),
                  _TechChip(label: 'Material 3', icon: Icons.palette),
                ],
              ),
            ),
            const BaseGap(Proximity.grouped),

            const Divider(),
            const BaseGap(Proximity.grouped),
          ],
        ),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _TechChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return BaseBadge(
      label: label,
      icon: icon,
      variant: BadgeVariant.primary,
      size: BadgeSize.medium,
    );
  }
}

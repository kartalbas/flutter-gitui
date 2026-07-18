import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../shared/components/base_badge.dart';
import '../../shared/components/base_dialog.dart';
import '../../shared/components/base_label.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/services/version_service.dart';
import '../../core/services/build_info.dart';

class AppAboutDialog extends HookConsumerWidget {
  const AppAboutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionService = ref.watch(versionServiceProvider);
    final version = useState<String>('...');

    useEffect(() {
      versionService.getCurrentVersion().then((v) => version.value = v);
      return null;
    }, []);

    return BaseDialog(
      title: 'About Flutter GitUI',
      icon: Icons.info_outline,
      variant: DialogVariant.normal,
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.commit,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.paddingM),
                  HeadlineSmallLabel('Flutter GitUI'),
                  const SizedBox(height: AppTheme.paddingXS),
                  TitleSmallLabel('Version ${version.value}'),
                  const SizedBox(height: AppTheme.paddingXS),
                  BodySmallLabel(
                    'Build: ${BuildInfo.displayCommit}',
                    textAlign: TextAlign.center,
                  ),
                  if (BuildInfo.displayDate.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    BodySmallLabel(
                      BuildInfo.displayDate,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.paddingL),

            // Description
            Center(
              child: BodyMediumLabel(
                'A cross-platform Git UI built with Flutter.',
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppTheme.paddingL),

            const Divider(),
            const SizedBox(height: AppTheme.paddingM),

            // Technology stack
            Center(child: TitleSmallLabel('Built with')),
            const SizedBox(height: AppTheme.paddingS),
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
            const SizedBox(height: AppTheme.paddingM),

            const Divider(),
            const SizedBox(height: AppTheme.paddingM),
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

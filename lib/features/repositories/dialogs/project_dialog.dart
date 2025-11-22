import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/workspace/models/workspace.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../generated/app_localizations.dart';

/// Result of the project dialog
class ProjectDialogResult {
  final String name;
  final String? description;
  final Color color;
  final String? icon;

  const ProjectDialogResult({
    required this.name,
    this.description,
    required this.color,
    this.icon,
  });
}

/// Dialog for creating or editing a project
class ProjectDialog extends StatefulWidget {
  final Workspace? project; // null for create, non-null for edit

  const ProjectDialog({
    super.key,
    this.project,
  });

  @override
  State<ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<ProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name);
    _descriptionController = TextEditingController(text: widget.project?.description);
    _selectedColor = widget.project?.color ?? WorkspaceColors.random();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.project != null;

    return BaseDialog(
      title: isEditing ? l10n.projectDialogEditTitle : l10n.projectDialogCreateTitle,
      icon: PhosphorIconsBold.folder,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project name
            LabelLargeLabel(
              l10n.projectNameLabel,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BaseTextField(
              controller: _nameController,
              hintText: l10n.enterProjectName,
              prefixIcon: PhosphorIconsRegular.textT,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.enterProjectNameValidation;
                }
                return null;
              },
              autofocus: true,
            ),

            const SizedBox(height: AppTheme.paddingL),

            // Project description
            LabelLargeLabel(
              l10n.projectDescriptionLabel,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BaseTextField(
              controller: _descriptionController,
              hintText: l10n.enterProjectDescription,
              prefixIcon: PhosphorIconsRegular.textAlignLeft,
              maxLines: 3,
            ),

            const SizedBox(height: AppTheme.paddingL),

            // Color picker
            LabelLargeLabel(
              l10n.projectColorLabel,
            ),
            const SizedBox(height: AppTheme.paddingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Wrap(
                spacing: AppTheme.paddingS,
                runSpacing: AppTheme.paddingS,
                children: WorkspaceColors.defaults.map((color) {
                  final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    child: Container(
                      width: AppTheme.iconXL * 2,
                      height: AppTheme.iconXL * 2,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              PhosphorIconsBold.check,
                              color: _getContrastingColor(color),
                              size: AppTheme.iconM,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: AppTheme.paddingM),

            // Preview
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.info,
                    size: AppTheme.iconS,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: AppTheme.paddingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LabelSmallLabel(
                          l10n.previewLabel,
                        ),
                        const SizedBox(height: AppTheme.paddingXS),
                        Row(
                          children: [
                            Container(
                              width: AppTheme.paddingXS,
                              height: AppTheme.iconS,
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            TitleSmallLabel(
                              _nameController.text.isEmpty ? l10n.projectNamePreviewPlaceholder : _nameController.text,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: isEditing ? l10n.saveProjectButton : l10n.createProjectButton,
          variant: ButtonVariant.primary,
          leadingIcon: isEditing ? PhosphorIconsBold.floppyDisk : PhosphorIconsBold.plus,
          onPressed: _handleSave,
        ),
      ],
    );
  }

  Color _getContrastingColor(Color color) {
    // Calculate luminance to determine if we should use black or white text
    final luminance = (0.299 * ((color.r * 255.0).round() & 0xff) + 0.587 * ((color.g * 255.0).round() & 0xff) + 0.114 * ((color.b * 255.0).round() & 0xff)) / 255;
    return luminance > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      final result = ProjectDialogResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        color: _selectedColor,
      );
      Navigator.of(context).pop(result);
    }
  }
}

/// Show project dialog
Future<ProjectDialogResult?> showProjectDialog(
  BuildContext context, {
  Workspace? project,
}) {
  return showDialog<ProjectDialogResult>(
    context: context,
    builder: (context) => ProjectDialog(project: project),
  );
}

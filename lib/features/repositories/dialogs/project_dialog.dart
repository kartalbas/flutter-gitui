import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/workspace/default_workspace_text.dart';
import '../../../core/workspace/models/workspace.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_layout.dart';

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

  const ProjectDialog({super.key, this.project});

  @override
  State<ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<ProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Color _selectedColor;

  /// Whether the edited workspace's text has been put into the fields already.
  bool _fieldsPrefilled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _selectedColor = widget.project?.color ?? WorkspaceColors.random();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fieldsPrefilled) return;
    _fieldsPrefilled = true;

    final project = widget.project;
    if (project != null) {
      // The words shown on screen, not the words in the file: the default
      // workspace stores neither its name nor its description, so editing it
      // has to start from what the user is actually looking at. _handleSave
      // maps an untouched submission back to "absent".
      final l10n = AppLocalizations.of(context)!;
      _nameController.text = project.displayName(l10n);
      _descriptionController.text = project.displayDescription(l10n) ?? '';
    }

    // The preview row renders the current name, so typing must rebuild the
    // dialog. Attached after the prefill, so filling the fields does not ask
    // for a rebuild while dependencies are still being resolved.
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.project != null;

    return BaseDialog(
      title: isEditing
          ? l10n.projectDialogEditTitle
          : l10n.projectDialogCreateTitle,
      // Drawn at Phosphor BOLD before the conversion: same folder, heavier
      // stroke. A role carries no weight (#249 conflict C3), so the header
      // mark now takes the ordinary one. Recorded and pinned, with the
      // measurement, by `test/shared/icons/icon_weight_census_test.dart`:
      // 6 of the 72 `BaseDialog.icon` sites were bold, and the folder mark is
      // drawn at the ordinary stroke 14 times elsewhere in the application.
      icon: IconRole.folder,
      // The description field is multiline; Enter inside it writes a newline,
      // Enter anywhere else saves. _handleSave validates the form itself.
      onSubmit: _handleSave,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project name
            BaseLabel(l10n.projectNameLabel, role: TextRole.control),
            const BaseGap(Proximity.related),
            BaseTextField(
              controller: _nameController,
              hintText: l10n.enterProjectName,
              prefixIcon: IconRole.textT,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.enterProjectNameValidation;
                }
                return null;
              },
              autofocus: true,
            ),

            const BaseGap(Proximity.separate),

            // Project description
            BaseLabel(l10n.projectDescriptionLabel, role: TextRole.control),
            const BaseGap(Proximity.related),
            BaseTextField(
              controller: _descriptionController,
              hintText: l10n.enterProjectDescription,
              prefixIcon: IconRole.textAlignLeft,
              maxLines: 3,
            ),

            const BaseGap(Proximity.separate),

            // Color picker
            BaseLabel(l10n.projectColorLabel, role: TextRole.control),
            const BaseGap(Proximity.related),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                all: Inset.normal,
                child: Wrap(
                  spacing: AppTheme.paddingS,
                  runSpacing: AppTheme.paddingS,
                  children: WorkspaceColors.defaults.map((color) {
                    final isSelected =
                        _selectedColor.toARGB32() == color.toARGB32();
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
                          // The chosen swatch's 3 px ring is a BORDER, and a
                          // border leaves with the surface it encloses. This
                          // one leaves rather sooner than most: the whole
                          // swatch grid is registered against
                          // `controls.seriesPicker`, the member that owns
                          // which colours exist and how the chosen one is
                          // marked, so drawing the ring from a tone here
                          // would half-migrate a construction that member
                          // deletes.
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
            ),

            const BaseGap(Proximity.grouped),

            // Preview
            Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                all: Inset.normal,
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.info,
                      size: AppTheme.iconS,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const BaseGap(Proximity.grouped),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BaseLabel(l10n.previewLabel, role: TextRole.micro),
                          const BaseGap(Proximity.hairline),
                          Row(
                            children: [
                              // The preview's colour stripe is a SHAPE, not
                              // a spacing: it was spelled with a padding and
                              // an icon token, which said nothing true about
                              // it. Four by sixteen is the swatch's geometry
                              // and it moves into `surfaces.badge` with the
                              // hand-painted preview around it.
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _selectedColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusXS,
                                  ),
                                ),
                              ),
                              const BaseGap(Proximity.related),
                              BaseLabel(
                                _nameController.text.isEmpty
                                    ? l10n.projectNamePreviewPlaceholder
                                    : _nameController.text,
                                role: TextRole.itemTitle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: isEditing ? l10n.saveProjectButton : l10n.createProjectButton,
          role: DialogActionRole.affirmative,
          // Both marks were written at Phosphor Bold before the conversion.
          // The role deliberately carries no weight (#249 conflict C3), and
          // the dialog's action slot renders through the standard button
          // path, so they now take the button's ordinary stroke like every
          // other button in the application. Of the 16 `DialogAction.icon`
          // sites, 2 were bold and 14 were not; `plus` alone is drawn at the
          // ordinary stroke 16 times elsewhere. Recorded and pinned by
          // `test/shared/icons/icon_weight_census_test.dart`.
          icon: isEditing ? IconRole.floppyDisk : IconRole.plus,
          onPressed: _handleSave,
        ),
      ],
    );
  }

  Color _getContrastingColor(Color color) {
    // Calculate luminance to determine if we should use black or white text
    final luminance =
        (0.299 * ((color.r * 255.0).round() & 0xff) +
            0.587 * ((color.g * 255.0).round() & 0xff) +
            0.114 * ((color.b * 255.0).round() & 0xff)) /
        255;
    return luminance > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  void _handleSave() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    // Text the user left exactly as the dialog presented it is still the
    // application's own wording for the default workspace, so it goes back to
    // the file as absent and keeps following the UI language. Everything else
    // is the user's own text and is stored as typed.
    final isDefault = widget.project?.isDefaultWorkspace ?? false;

    final result = ProjectDialogResult(
      name: isDefault ? storedDefaultWorkspaceName(name, l10n) : name,
      description: isDefault
          ? storedDefaultWorkspaceDescription(description, l10n)
          : (description.isEmpty ? null : description),
      color: _selectedColor,
    );
    Navigator.of(context).pop(result);
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

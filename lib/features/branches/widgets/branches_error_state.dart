import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

/// Error state for branches screen when loading fails
class BranchesErrorState extends StatelessWidget {
  final Object error;

  const BranchesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          // The glyph and the headline are members of one statement: `grouped`,
          // which Material answers with the 16 pixels this line used to name.
          const BaseGap(Proximity.grouped),
          // The error state's headline, at the same rung as every other one.
          BaseLabel(
            AppLocalizations.of(
              context,
            )!.errorLoadingBranches(error.toString()),
            role: TextRole.pageTitle,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

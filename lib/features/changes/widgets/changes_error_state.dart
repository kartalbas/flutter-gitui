import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

/// Error state for changes screen when status loading fails
class ChangesErrorState extends StatelessWidget {
  final Object error;

  const ChangesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          // The hero glyph and the headline are two groups inside one region:
          // `separate`.
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.errorLoadingStatus,
            role: TextRole.pageTitle,
          ),
          // The headline and the message explaining it are two parts of one
          // statement: `related`.
          const BaseGap(Proximity.related),
          BaseLabel(
            error.toString(),
            role: TextRole.detail,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

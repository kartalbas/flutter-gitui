import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/components/base_layout.dart';

/// Result of a Git command execution
class GitCommandResult {
  final String command;
  final String stdout;
  final String stderr;
  final int exitCode;
  final Duration executionTime;

  GitCommandResult({
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.executionTime,
  });

  bool get isSuccess => exitCode == 0;
  bool get hasOutput => stdout.isNotEmpty || stderr.isNotEmpty;

  String get fullOutput {
    final buffer = StringBuffer();
    if (stdout.isNotEmpty) {
      buffer.writeln('=== STDOUT ===');
      buffer.writeln(stdout);
    }
    if (stderr.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('=== STDERR ===');
      buffer.writeln(stderr);
    }
    return buffer.toString();
  }
}

/// Dialog that shows Git command output
class GitOutputDialog extends StatefulWidget {
  final GitCommandResult result;
  final bool autoCloseOnSuccess;
  final Duration autoCloseDuration;

  const GitOutputDialog({
    super.key,
    required this.result,
    this.autoCloseOnSuccess = true,
    this.autoCloseDuration = const Duration(seconds: 3),
  });

  /// Show the dialog and return when it closes
  static Future<void> show(
    BuildContext context,
    GitCommandResult result, {
    bool autoCloseOnSuccess = true,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GitOutputDialog(
        result: result,
        autoCloseOnSuccess: autoCloseOnSuccess,
      ),
    );
  }

  @override
  State<GitOutputDialog> createState() => _GitOutputDialogState();
}

class _GitOutputDialogState extends State<GitOutputDialog> {
  bool _keepOpen = false;
  Timer? _autoCloseTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();

    // Auto-close on success unless user checks "Keep open"
    if (widget.result.isSuccess && widget.autoCloseOnSuccess) {
      _remainingSeconds = widget.autoCloseDuration.inSeconds;
      _startAutoCloseTimer();
    }
  }

  void _startAutoCloseTimer() {
    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0 && !_keepOpen) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard() {
    final text =
        '''
Command: git ${widget.result.command}
Exit Code: ${widget.result.exitCode}
Execution Time: ${widget.result.executionTime.inMilliseconds}ms

${widget.result.fullOutput}
''';

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.outputCopiedToClipboard),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return BaseDialog(
      title: result.isSuccess
          ? AppLocalizations.of(context)!.gitCommandSuccessful
          : AppLocalizations.of(context)!.gitCommandFailed,
      icon: result.isSuccess ? IconRole.checkCircle : IconRole.xCircle,
      variant: result.isSuccess
          ? DialogVariant.normal
          : DialogVariant.destructive,
      barrierDismissible: true,
      onSubmit: () => Navigator.of(context).pop(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto-close countdown banner. Its bottom margin was a one-sided
          // inset, which is a gap wearing a padding idiom: the distance
          // belongs between the banner and the section below it, so the
          // column states it and the banner states none.
          if (_remainingSeconds > 0 && !_keepOpen) ...<Widget>[
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              // The banner paints its own fill, so it states the paired
              // foreground once here; the label inside then says nothing
              // about colour, which is the arrangement that cannot be got
              // wrong.
              child: BaseInset(
                all: Inset.tight,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  // The glyph is published exactly the way the words above it
                  // are - once, by the surface that paints underneath both -
                  // so the mark inside only has to say which idea it stands
                  // for and how much room it is owed. The colour leaves with
                  // the fill it pairs with when this banner becomes a member.
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    child: Row(
                      children: [
                        // A countdown mark sitting inside one line of text.
                        const BaseIcon(
                          IconRole.clock,
                          scale: ControlScale.compact,
                        ),
                        const BaseGap(Proximity.related),
                        BaseLabel(
                          AppLocalizations.of(
                            context,
                          )!.closingInSeconds(_remainingSeconds),
                          role: TextRole.detail,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const BaseGap(Proximity.grouped),
          ],
          // Command executed
          _buildCommandSection(),

          const BaseGap(Proximity.grouped),

          // Execution details
          _buildExecutionDetails(),

          const BaseGap(Proximity.grouped),

          // Output section
          Flexible(child: _buildOutputSection()),

          const BaseGap(Proximity.grouped),

          // Keep open checkbox (only for successful commands)
          if (result.isSuccess && widget.autoCloseOnSuccess)
            CheckboxListTile(
              value: _keepOpen,
              onChanged: (value) {
                setState(() {
                  _keepOpen = value ?? false;
                });
              },
              title: Text(AppLocalizations.of(context)!.checkboxKeepDialogOpen),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
      actions: [
        // Copying the git output leaves the dialog open, so it is a peer of
        // closing rather than a second way to finish.
        DialogAction(
          label: AppLocalizations.of(context)!.copyOutput,
          role: DialogActionRole.neutral,
          icon: IconRole.copy,
          onPressed: _copyToClipboard,
        ),

        // The dialog reports what git said and asks for nothing else, so
        // acknowledging it is what completes it.
        DialogAction(
          label: AppLocalizations.of(context)!.close,
          role: DialogActionRole.affirmative,
          icon: IconRole.x,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildCommandSection() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: BaseInset(
        all: Inset.normal,
        child: Row(
          children: [
            // The mark that says the line beside it is a command, drawn in
            // the application's own accent. It sits inside one line of text,
            // which is what decides how much room it is owed.
            const BaseIcon(
              IconRole.terminal,
              scale: ControlScale.compact,
              tone: Tone.accent,
            ),
            const BaseGap(Proximity.related),
            Expanded(
              // The command git was actually given. Alignment is meaning here
              // rather than style, and the user copies this line, so it is
              // said as code and stays selectable.
              child: BaseLabel(
                'git ${widget.result.command}',
                role: TextRole.code,
                selectable: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionDetails() {
    return Row(
      children: [
        _buildDetailChip(
          AppLocalizations.of(context)!.exitCode,
          widget.result.exitCode.toString(),
          widget.result.isSuccess
              ? context.gitColors.added
              : context.gitColors.deleted,
        ),
        const BaseGap(Proximity.related),
        _buildDetailChip(
          AppLocalizations.of(context)!.time,
          '${widget.result.executionTime.inMilliseconds}ms',
          Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildDetailChip(String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: BaseInset(
        x: Inset.normal,
        y: Inset.tight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BaseLabel(label, role: TextRole.micro, tone: Tone.muted),
            const BaseGap(Proximity.hairline),
            // Deliberately still the old label: this helper's Color parameter
            // also paints the chip's fill, border and icon, so it can only
            // become a Tone when the whole chip moves onto `surfaces.badge` in
            // the surface sub-phase - the application cannot resolve a Tone to
            // a Color for its own decoration, and the seam is right to forbid
            // that.
            LabelMediumLabel(value, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputSection() {
    final result = widget.result;

    if (!result.hasOutput) {
      // A command that printed nothing stands in place of this section's whole
      // content, which is the empty-state hero rather than a column this dialog
      // arranges itself (#430). `AppTheme.iconXL * 2` left with it: the member
      // accepts no size, so the arithmetic that produced a 64 px glyph here was
      // a leak by construction - and "No output" is the headline of the state,
      // which is what TextRole.pageTitle is for.
      return EmptyStateWidget(
        icon: PhosphorIconsRegular.fileText,
        title: AppLocalizations.of(context)!.noOutput,
        message: '',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: result.isSuccess
              ? Theme.of(context).colorScheme.outline
              : context.gitColors.deleted.withValues(alpha: 0.3),
        ),
      ),
      child: BaseInset(
        all: Inset.normal,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STDOUT
              if (result.stdout.isNotEmpty) ...[
                BaseLabel('STDOUT', role: TextRole.micro, tone: Tone.gitAdded),
                const BaseGap(Proximity.related),
                BaseLabel(result.stdout, role: TextRole.detail),
              ],

              // STDERR
              if (result.stderr.isNotEmpty) ...[
                if (result.stdout.isNotEmpty) const BaseGap(Proximity.grouped),
                BaseLabel(
                  'STDERR',
                  role: TextRole.micro,
                  tone: Tone.gitDeleted,
                ),
                const BaseGap(Proximity.related),
                BaseLabel(
                  result.stderr,
                  role: TextRole.detail,
                  tone: Tone.gitDeleted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

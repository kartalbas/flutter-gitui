import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/theme/app_theme.dart';

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
      icon: result.isSuccess
          ? PhosphorIconsRegular.checkCircle
          : PhosphorIconsRegular.xCircle,
      variant: result.isSuccess
          ? DialogVariant.normal
          : DialogVariant.destructive,
      barrierDismissible: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto-close countdown banner
          if (_remainingSeconds > 0 && !_keepOpen)
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingS),
              margin: const EdgeInsets.only(bottom: AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.clock,
                    size: AppTheme.paddingM,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  BodySmallLabel(
                    AppLocalizations.of(
                      context,
                    )!.closingInSeconds(_remainingSeconds),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          // Command executed
          _buildCommandSection(),

          const SizedBox(height: AppTheme.paddingM),

          // Execution details
          _buildExecutionDetails(),

          const SizedBox(height: AppTheme.paddingM),

          // Output section
          Flexible(child: _buildOutputSection()),

          const SizedBox(height: AppTheme.paddingM),

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
        // Copy button
        BaseButton(
          label: AppLocalizations.of(context)!.copyOutput,
          variant: ButtonVariant.tertiary,
          leadingIcon: PhosphorIconsRegular.copy,
          onPressed: _copyToClipboard,
        ),

        // Close button
        BaseButton(
          label: AppLocalizations.of(context)!.close,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.x,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildCommandSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.paddingS),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.terminal,
            size: AppTheme.iconS,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.paddingS),
          Expanded(
            child: SelectableText(
              'git ${widget.result.command}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionDetails() {
    return Row(
      children: [
        _buildDetailChip(
          AppLocalizations.of(context)!.exitCode,
          widget.result.exitCode.toString(),
          widget.result.isSuccess ? AppTheme.gitAdded : AppTheme.gitDeleted,
        ),
        const SizedBox(width: AppTheme.paddingS),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingM,
        vertical: AppTheme.paddingS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LabelSmallLabel(
            label,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.paddingXS),
          LabelMediumLabel(value, color: color),
        ],
      ),
    );
  }

  Widget _buildOutputSection() {
    final result = widget.result;

    if (!result.hasOutput) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.fileText,
              size: AppTheme.iconXL * 2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.paddingM),
            BodyLargeLabel(
              AppLocalizations.of(context)!.noOutput,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.paddingS),
        border: Border.all(
          color: result.isSuccess
              ? Theme.of(context).colorScheme.outline
              : AppTheme.gitDeleted.withValues(alpha: 0.3),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STDOUT
            if (result.stdout.isNotEmpty) ...[
              LabelSmallLabel('STDOUT', color: AppTheme.gitAdded),
              const SizedBox(height: AppTheme.paddingS),
              BodySmallLabel(
                result.stdout,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ],

            // STDERR
            if (result.stderr.isNotEmpty) ...[
              if (result.stdout.isNotEmpty)
                const SizedBox(height: AppTheme.paddingM),
              LabelSmallLabel('STDERR', color: AppTheme.gitDeleted),
              const SizedBox(height: AppTheme.paddingS),
              BodySmallLabel(result.stderr, color: AppTheme.gitDeleted),
            ],
          ],
        ),
      ),
    );
  }
}

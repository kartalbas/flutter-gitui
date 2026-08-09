import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BadgeFact,
        BadgeSpec,
        ControlScale,
        IconRole,
        Inset,
        NoticeSpec,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_badge.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_dialog.dart';
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
class GitOutputDialog extends StatelessWidget {
  final GitCommandResult result;
  final bool autoCloseOnSuccess;
  final Duration autoCloseDuration;

  const GitOutputDialog({
    super.key,
    required this.result,
    this.autoCloseOnSuccess = true,
    this.autoCloseDuration = const Duration(seconds: 3),
  });

  /// Show the dialog and return when it closes, on the skin's own route.
  ///
  /// The frame is a fact of [result] and never changes while the dialog is
  /// up - the title, the mark, the tone and both actions are the same on
  /// every build - so the whole dialog can be stated before it exists and
  /// reach `Overlays.dialog` instead of Material's `showDialog`. What DOES
  /// change over the dialog's life - the countdown, the keep-open checkbox -
  /// is dialog content, and content crosses the seam live inside its port
  /// ([_GitOutputContent] keeps its own timer and pops its own route).
  static Future<void> show(
    BuildContext context,
    GitCommandResult result, {
    bool autoCloseOnSuccess = true,
  }) async {
    // The frame's action closures need a context that is alive when the
    // action is PRESSED, not the opener's element, which can be disposed
    // while the dialog is up (a background status refresh re-sorting the
    // repository list under the barrier is enough). The content is the live
    // half of the dialog, so this key is how the frame reaches it. Created
    // once per show call - never inside a build method, where a fresh key
    // every build would remount the content and restart its timer.
    final GlobalKey contentKey = GlobalKey();
    await BaseDialog.show<void>(
      context: context,
      dialog: _dialog(
        context,
        result: result,
        autoCloseOnSuccess: autoCloseOnSuccess,
        autoCloseDuration: const Duration(seconds: 3),
        contentKey: contentKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _dialog(
    context,
    result: result,
    autoCloseOnSuccess: autoCloseOnSuccess,
    autoCloseDuration: autoCloseDuration,
  );

  /// Builds the frame. On the [show] path [context] is the OPENER's, alive
  /// only at open time, so nothing here may walk it at press time: the
  /// navigator is captured once now (it outlives the opener), and the copy
  /// action reaches the live content through [contentKey]. On the widget
  /// path (`build`) the context IS inside the route for the dialog's whole
  /// life, so [contentKey] stays null and the context serves directly.
  static BaseDialog _dialog(
    BuildContext context, {
    required GitCommandResult result,
    required bool autoCloseOnSuccess,
    required Duration autoCloseDuration,
    GlobalKey? contentKey,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final NavigatorState navigator = Navigator.of(context);
    return BaseDialog(
      title: result.isSuccess
          ? l10n.gitCommandSuccessful
          : l10n.gitCommandFailed,
      icon: result.isSuccess ? IconRole.checkCircle : IconRole.xCircle,
      variant: result.isSuccess
          ? DialogVariant.normal
          : DialogVariant.destructive,
      barrierDismissible: true,
      onSubmit: () => navigator.pop(),
      content: _GitOutputContent(
        key: contentKey,
        result: result,
        autoCloseOnSuccess: autoCloseOnSuccess,
        autoCloseDuration: autoCloseDuration,
      ),
      actions: [
        // Copying the git output leaves the dialog open, so it is a peer of
        // closing rather than a second way to finish. The notice it raises
        // anchors to the content's element - the one context guaranteed to
        // be alive while the button is pressable.
        DialogAction(
          label: l10n.copyOutput,
          role: DialogActionRole.neutral,
          icon: IconRole.copy,
          onPressed: () {
            final BuildContext? live = contentKey == null
                ? context
                : contentKey.currentContext;
            if (live != null) _copyToClipboard(live, result);
          },
        ),

        // The dialog reports what git said and asks for nothing else, so
        // acknowledging it is what completes it.
        DialogAction(
          label: l10n.close,
          role: DialogActionRole.affirmative,
          icon: IconRole.x,
          onPressed: () => navigator.pop(),
        ),
      ],
    );
  }

  static void _copyToClipboard(BuildContext context, GitCommandResult result) {
    final text =
        '''
Command: git ${result.command}
Exit Code: ${result.exitCode}
Execution Time: ${result.executionTime.inMilliseconds}ms

${result.fullOutput}
''';

    Clipboard.setData(ClipboardData(text: text));

    // The clipboard now holds what the dialog showed: something that finished
    // and finished well, which is what the notice says. Its fill, its
    // placement and how long two seconds of "brief" lasts are the skin's.
    Overlays.notify(
      context,
      NoticeSpec(
        tone: Tone.success,
        title: AppLocalizations.of(context)!.outputCopiedToClipboard,
      ),
    );
  }
}

/// The live half of the dialog: the countdown, the keep-open checkbox and the
/// output sections, owning the auto-close timer so the dialog's FRAME can be
/// stated once at open.
class _GitOutputContent extends StatefulWidget {
  const _GitOutputContent({
    super.key,
    required this.result,
    required this.autoCloseOnSuccess,
    required this.autoCloseDuration,
  });

  final GitCommandResult result;
  final bool autoCloseOnSuccess;
  final Duration autoCloseDuration;

  @override
  State<_GitOutputContent> createState() => _GitOutputContentState();
}

class _GitOutputContentState extends State<_GitOutputContent> {
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

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The auto-close countdown: a count riding on the dialog it belongs
        // to, which is `surfaces.badge`'s own question, said once. The pill
        // it used to hand-paint is the member's now — its fill, its corner,
        // its inset, its glyph size and its type step move together, because
        // a mark this small reads as a rendering fault when only one of them
        // changes (the member's own rule). What leaves with the fill is the
        // pair of ambient publications underneath it: a `DefaultTextStyle`
        // and an `IconTheme` naming `onPrimaryContainer` for a container the
        // application had just painted itself, which is precisely the
        // fill-and-foreground pairing the seam exists to take off the
        // application. `Tone.accent` is what that pairing MEANT.
        //
        // Not `surfaces.banner`, and that is a decision rather than an
        // oversight: `BannerSpec`'s own doc says its actions exist because
        // `MaterialBanner` asserts a non-empty list, so an action-less
        // banner is the shape the spec says makes the canonical widget
        // unreachable — and a banner is a full-width `titleMedium`
        // statement, three times as loud as the quiet strip this is.
        //
        // Its bottom margin was a one-sided inset, which is a gap wearing a
        // padding idiom: the distance belongs between the countdown and the
        // section below it, so the column states it and the pill states none.
        if (_remainingSeconds > 0 && !_keepOpen) ...<Widget>[
          BaseBadge(
            label: AppLocalizations.of(
              context,
            )!.closingInSeconds(_remainingSeconds),
            icon: IconRole.clock,
            variant: BadgeVariant.primary,
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
    );
  }

  /// **Here is one self-contained object** - the command git was given, which
  /// is the first thing this dialog exists to report and the line the user
  /// copies out of it.
  ///
  /// The fill, the corner and the edge were that card drawn by hand, and they
  /// were drawn TWICE in this file: this section and [_buildOutputSection]
  /// below were the same `surfaceContainerHighest` box at the same corner
  /// behind the same 1 px `outline`, restated line for line. One member draws
  /// both now, so the two can no longer drift apart - and neither can round
  /// differently from the commit-message and details cards in
  /// `commit_details_panel.dart`, which are the same construction one screen
  /// over and already went through the member.
  ///
  /// `Inset.normal` is stated rather than left to the card's default, because
  /// the hand-painted copy held its content at the ordinary reading distance
  /// and a card's default is deliberately more generous.
  Widget _buildCommandSection() {
    return BaseCard(
      isSelectable: false,
      inset: Inset.normal,
      content: Row(
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
    );
  }

  Widget _buildExecutionDetails() {
    return Row(
      children: [
        // What the exit code MEANS, in the words for it. It used to say
        // `Tone.gitAdded`/`Tone.gitDeleted` - the file-status palette - about a
        // process's return value, which names neither a new file nor a deleted
        // one. Exit code 0 is "this finished, and it finished well", which is
        // `Tone.success` verbatim, and anything else is the failure the card
        // below and the dialog's own frame already call `Tone.danger`. Under
        // this skin the success half does not move a pixel (`Tone.success` and
        // `Tone.gitAdded` both resolve to the git palette's added colour); the
        // failure half moves from that palette's deleted red to the scheme's
        // error role, which is the one red the rest of the dialog uses.
        _buildDetailChip(
          AppLocalizations.of(context)!.exitCode,
          widget.result.exitCode.toString(),
          widget.result.isSuccess ? Tone.success : Tone.danger,
        ),
        const BaseGap(Proximity.related),
        _buildDetailChip(
          AppLocalizations.of(context)!.time,
          '${widget.result.executionTime.inMilliseconds}ms',
          Tone.accent,
        ),
      ],
    );
  }

  /// One fact about the run, as the paired badge it always was: what the fact
  /// is CALLED beside what the fact SAYS.
  ///
  /// This is the conversion the old helper's own comment asked for. Its
  /// `Color` parameter painted the fill, the border and the value at once, so
  /// naming the meaning was impossible while the decoration stayed here; with
  /// the whole chip on `surfaces.badge` the parameter is a [Tone] and the
  /// application never touches a colour again.
  ///
  /// The pairing is what fixes a real defect rather than merely moving it.
  /// The chip used to wash its ENTIRE surface in the value's colour - a red
  /// box behind the words "Exit Code", which mean nothing red - and the
  /// member's rule is that one wash cannot mean two things: a paired badge
  /// takes the neutral chip's fill and each half carries its own meaning as
  /// its foreground, which is where the distinction actually lives.
  Widget _buildDetailChip(String label, String value, Tone tone) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.surfaces.badge(
          inner,
          BadgeSpec(
            label: label,
            // "Exit Code", "Time": the name of the fact, secondary to the
            // fact itself, which is exactly what the muted tone says.
            tone: Tone.muted,
            secondary: BadgeFact(label: value, tone: tone),
          ),
        );
      });

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

    // **Here is one self-contained object** again: everything git printed.
    // The same hand-painted box as the command section above it, down to the
    // fill, the corner and the edge, so it becomes the same member.
    //
    // The edge carried one extra statement and it is kept, said as a meaning
    // instead of as a colour: the box used to swap its border for the git
    // palette's DELETED colour at 30 % whenever the run failed. `Tone.
    // gitDeleted` means "a tracked file that is gone", which is not what a
    // failed push is, and the application was reaching past the seam for the
    // colour itself. `Tone.danger` is the word this application already uses
    // for a failure - `EmptyStateSpec.tone`'s own doc prescribes it, and both
    // browse panels' error states say it - and the card member paints a tone
    // exactly where the hand-painted copy did: on the edge, leaving the fill
    // and the foreground alone.
    return BaseCard(
      isSelectable: false,
      inset: Inset.normal,
      tone: result.isSuccess ? Tone.neutral : Tone.danger,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STDOUT. Its heading said `Tone.gitAdded` - "a file git has never
            // seen before, now staged for its first commit" - about the
            // standard output STREAM, which is a meaning rounded onto the
            // nearest green. Ordinary output has no colour, and saying nothing
            // is how `Tone.neutral` is said.
            //
            // The output itself is `TextRole.code`, which is the role's own
            // definition ("diffs, hashes, paths, command output") and what the
            // command line six lines above already says. This file used to say
            // "here is machine output" at two type steps - monospaced up there,
            // proportional down here - which is the one thing alignment-bearing
            // text cannot afford.
            if (result.stdout.isNotEmpty) ...[
              BaseLabel('STDOUT', role: TextRole.micro),
              const BaseGap(Proximity.related),
              BaseLabel(result.stdout, role: TextRole.code),
            ],

            // STDERR: what went wrong, which is `Tone.danger` and not the git
            // palette's deleted-file colour. Said once for the heading and its
            // content, in the same word the card's own edge now carries, so one
            // failure is one red rather than two.
            if (result.stderr.isNotEmpty) ...[
              if (result.stdout.isNotEmpty) const BaseGap(Proximity.grouped),
              BaseLabel('STDERR', role: TextRole.micro, tone: Tone.danger),
              const BaseGap(Proximity.related),
              BaseLabel(result.stderr, role: TextRole.code, tone: Tone.danger),
            ],
          ],
        ),
      ),
    );
  }
}

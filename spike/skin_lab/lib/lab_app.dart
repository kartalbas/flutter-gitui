// The running lab.
//
// Its job is to answer the RED criterion "the skins cannot coexist in one
// running app" with running code: ONE MaterialApp root, ONE Navigator, three
// SkinScopes side by side, every frozen component rendered under each. If the
// three skins can be alive simultaneously in one tree - and each can open its
// own overlay through that one Navigator - then swapping between them at
// runtime is a strictly easier problem.
//
// ignore_for_file: avoid_dialog

import 'package:flutter/material.dart';

import 'app_stubs.dart';
import 'frozen/frozen_app_shell.dart';
import 'frozen/frozen_base_button.dart';
import 'frozen/frozen_base_dialog.dart';
import 'frozen/frozen_base_filter_chip.dart';
import 'frozen/frozen_base_text_field.dart';
import 'skin.dart';
import 'skins/cupertino_skin.dart';
import 'skins/fluent_skin.dart';
import 'skins/material_skin.dart';

const List<Skin> kSkins = <Skin>[MaterialSkin(), CupertinoSkin(), FluentSkin()];

/// The union of every registered skin's localization delegates, installed once
/// at the single app root.
///
/// This exists because the day-one probe showed `fluent.showDialog` asserts
/// `FluentLocalizations` before it pushes anything. A skin therefore cannot be
/// self-contained at the widget level; it has a claim on the app root.
Iterable<LocalizationsDelegate<Object?>> get kAllSkinDelegates =>
    <LocalizationsDelegate<Object?>>[
      for (final Skin skin in kSkins) ...skin.localizationsDelegates,
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ];

void main() => runApp(const SkinLabApp());

class SkinLabApp extends StatelessWidget {
  const SkinLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skin_lab',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: kAllSkinDelegates,
      home: const SkinLabHome(),
    );
  }
}

class SkinLabHome extends StatelessWidget {
  const SkinLabHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final Skin skin in kSkins)
            Expanded(
              child: SkinColumn(key: ValueKey<String>(skin.id), skin: skin),
            ),
        ],
      ),
    );
  }
}

/// One column per skin. Everything below the [SkinScope] renders through that
/// skin; the three columns are alive at the same time in the same tree.
class SkinColumn extends StatefulWidget {
  const SkinColumn({super.key, required this.skin});

  final Skin skin;

  @override
  State<SkinColumn> createState() => _SkinColumnState();
}

class _SkinColumnState extends State<SkinColumn> {
  bool _filterSelected = false;
  int _choiceIndex = 0;
  int _destination = 0;
  bool _railExtended = false;

  @override
  Widget build(BuildContext context) {
    return SkinScope(
      skin: widget.skin,
      child: widget.skin.wrapTheme(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                widget.skin.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: <Widget>[
                    // All seven variants, so a variant that cannot be mapped
                    // is visible rather than argued about.
                    for (final ButtonVariant variant in ButtonVariant.values)
                      FrozenBaseButton(
                        label: variant.name,
                        variant: variant,
                        leadingIcon: PhosphorIconsRegular.gitBranch,
                        onPressed: () {},
                      ),
                    const FrozenBaseButton(
                      label: 'loading',
                      isLoading: true,
                      onPressed: null,
                    ),
                    Row(
                      children: <Widget>[
                        for (final ButtonSize size in ButtonSize.values)
                          FrozenBaseIconButton(
                            icon: PhosphorIconsRegular.folder,
                            tooltip: 'Open (${size.name})',
                            size: size,
                            onPressed: () {},
                          ),
                        const FrozenBaseIconButton(
                          icon: PhosphorIconsRegular.gearSix,
                          tooltip: 'Toggle',
                          isSelected: true,
                          onPressed: null,
                        ),
                      ],
                    ),
                    for (final TextFieldVariant v in TextFieldVariant.values)
                      FrozenBaseTextField(
                        label: 'Branch name',
                        hintText: 'feature/...',
                        helperText: 'lowercase, no spaces',
                        prefixIcon: PhosphorIconsRegular.gitBranch,
                        variant: v,
                        showClearButton: true,
                      ),
                    FrozenBaseFilterChip(
                      label: 'Clean only',
                      count: 12,
                      showCount: true,
                      selected: _filterSelected,
                      onSelected: (bool v) =>
                          setState(() => _filterSelected = v),
                    ),
                    FrozenChoiceChipGroup(
                      options: const <ChoiceOption>[
                        ChoiceOption(label: 'feature'),
                        ChoiceOption(label: 'bugfix'),
                        ChoiceOption(label: 'hotfix'),
                      ],
                      selectedIndex: _choiceIndex,
                      onSelected: (int i) => setState(() => _choiceIndex = i),
                    ),
                    // A Builder, because `BaseDialog.show(context:)` resolves
                    // the skin from the context it is HANDED. In the app that
                    // is automatic (one skin, installed at the root); in this
                    // three-column lab the outer build context sits above the
                    // SkinScope, so the call would find no skin. Worth
                    // recording as good news: the existing `context` parameter
                    // already carries the skin, so the route seam needs no new
                    // argument at any of the 14 `BaseDialog.show` call sites.
                    Builder(
                      builder: (BuildContext context) => FrozenBaseButton(
                        label: 'Open dialog',
                        variant: ButtonVariant.secondary,
                        onPressed: () => _openDialog(context),
                      ),
                    ),
                    SizedBox(
                      height: 260,
                      child: FrozenAppShell(
                        selectedIndex: _destination,
                        onDestinationSelected: (int i) =>
                            setState(() => _destination = i),
                        railExtended: _railExtended,
                        onToggleRailExtended: () =>
                            setState(() => _railExtended = !_railExtended),
                        destinations: const <ShellDestination>[
                          ShellDestination(
                            label: 'Repositories',
                            icon: PhosphorIconsRegular.folder,
                            selectedIcon: PhosphorIconsRegular.folder,
                          ),
                          ShellDestination(
                            label: 'Changes',
                            icon: PhosphorIconsRegular.gitBranch,
                            selectedIcon: PhosphorIconsBold.gitBranch,
                            badgeCount: 7,
                          ),
                          ShellDestination(
                            label: 'History',
                            icon: PhosphorIconsRegular.clockCounterClockwise,
                            selectedIcon:
                                PhosphorIconsRegular.clockCounterClockwise,
                          ),
                        ],
                        toolbar: const SizedBox(
                          height: 36,
                          child: Center(child: Text('toolbar')),
                        ),
                        body: const Center(child: Text('content')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDialog(BuildContext context) {
    // The route is opened through the SHARED Navigator of the one MaterialApp
    // root; only the skin differs. That is the coexistence claim.
    FrozenBaseDialog.show<bool>(
      context: context,
      dialog: FrozenBaseDialog(
        title: 'Delete branch?',
        content: const Text('This action cannot be undone.'),
        variant: DialogVariant.destructive,
        maxWidth: 650,
        // Call order: dismissive first, affirmative last - the Material and
        // Apple convention, and the wrong order for Fluent 2. Left uncorrected
        // on purpose; see fluent_skin.dart's `actions` note.
        actions: <Widget>[
          FrozenBaseButton(
            label: 'Cancel',
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FrozenBaseButton(
            label: 'Delete',
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

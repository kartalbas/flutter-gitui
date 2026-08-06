Flutter GitUI for macOS — unsigned build
========================================

This build is NOT signed with an Apple Developer ID certificate and NOT
notarised. The app itself is the same as the Windows and Linux releases;
only the signature is missing. Because of that, macOS Gatekeeper will
block the first launch with a message such as:

    "Flutter GitUI" is damaged and can't be opened. You should move it
    to the Bin.

or

    "Flutter GitUI" can't be opened because Apple cannot check it for
    malicious software.

The app is not damaged. This is the standard macOS response to any app
downloaded from the internet without a paid Apple Developer signature.

How to run it anyway
--------------------

1. Move "Flutter GitUI.app" into your Applications folder.
2. Double-click the app once and dismiss the warning dialog.
3. Open System Settings -> Privacy & Security, scroll down to the
   Security section: it now shows a note that "Flutter GitUI" was
   blocked. Click "Open Anyway" and confirm the follow-up dialog.
4. The app starts. macOS remembers the decision, so every later launch
   behaves normally.

If the Security section offers no "Open Anyway" button (some macOS
versions show only the "damaged" dialog for unsigned apps), remove the
quarantine flag from the app in Terminal instead:

    xattr -dr com.apple.quarantine "/Applications/Flutter GitUI.app"

and launch it again.

If the app still refuses to start after being allowed, please report it:
https://github.com/kartalbas/flutter-gitui/issues

Signed and notarised builds will replace this arrangement once the
project holds an Apple Developer Program membership; those will launch
without any of the steps above.

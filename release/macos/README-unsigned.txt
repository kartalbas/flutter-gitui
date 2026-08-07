Flutter GitUI for macOS — unsigned build
========================================

This build is NOT signed with an Apple Developer ID certificate and NOT
notarised. The application itself is the same build as the Windows and
Linux releases; what it lacks is Apple's signature. Because of that,
macOS Gatekeeper will block the first launch with a message such as:

    "Flutter GitUI" is damaged and can't be opened. You should move it
    to the Bin.

or

    "Flutter GitUI" can't be opened because Apple cannot check it for
    malicious software.

The app is not damaged. This is the standard macOS response to any app
downloaded from the internet without a paid Apple Developer signature,
and it is a one-time hurdle: once you have allowed the app as described
below, it opens like any other application and keeps doing so.

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

If it quits the moment you open it
----------------------------------

That is a different failure from the one above — the app is not being
blocked, it is being ended — and this release is the attempt to fix it.
Unsigned builds before this one were signed with the macOS "hardened
runtime", a protection the system applies when it starts a program and
that Apple built to work together with a paid Developer ID signature.
This build no longer carries it. The flag was only ever needed for
Apple's notarisation, which an unsigned build does not go through, so on
this download it could restrict the app but never help it.

Before any macOS archive is published, the build pipeline now unpacks it
on a real Mac, checks that its signature is valid and free of that flag,
and then starts the app there to see that the system does not refuse to
run it. That is a real check and not a promise — but it runs on Apple's
build machines, and no machine can stand in for yours.

So if this copy still quits immediately, please do not treat the matter
as closed: say so on the original report rather than opening a new one,
because it would mean the cause is something else, and this project is
developed without a Mac and cannot find it without you.

    https://github.com/kartalbas/flutter-gitui/issues/421

Useful in that report: your macOS version, whether the Mac has Apple
silicon or an Intel processor, and the crash report macOS offers (also
found later in Console.app under "Crash Reports"). Most useful of all is
what the app prints when you start it from Terminal, which is where
macOS explains a refusal it otherwise only carries out:

    "/Applications/Flutter GitUI.app/Contents/MacOS/Flutter GitUI"

Updating this build
-------------------

This build does not update itself. It still checks for new versions and
tells you when one exists, but it will not replace its own bundle,
because the replacement would be unsigned as well: macOS remembers the
permission you gave in step 3 for this exact copy of the app, and a copy
it has never seen has to be allowed all over again. An update that ends
in "is damaged and can't be opened" is worse than no update at all, so
the app names the new version and leaves the swap to you: download it
from the releases page and repeat the steps above.

    https://github.com/kartalbas/flutter-gitui/releases

Signed and notarised builds will replace this arrangement once the
project holds an Apple Developer Program membership; those will launch
without any of the steps above, and they do update themselves.

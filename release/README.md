# Release

Releases are produced by `.github/workflows/release.yml`, triggered by pushing a tag of the form `v*.*.*`. Publishing the release then triggers `.github/workflows/publish-stores.yml`, which carries the two package-store channels (winget and the Snap Store). Nothing in this directory builds or publishes the application any more; what remains is either consumed by those workflows or shipped alongside the application.

## How a release happens

```bash
git tag -a v0.5.0 -m "0.5.0"
git push origin v0.5.0
```

The workflow builds Windows, Linux and macOS on their own runners, packs a flat archive per platform, derives the pre-release flag from the tag (any version containing `-` is a pre-release), writes a `latest-<platform>.json` manifest carrying the SHA-256 of the Windows and Linux archives, and opens a **draft** release with everything attached.

The draft is the gate: assets of a draft are neither served for download nor returned by the API the client polls, so nothing reaches a user until a human publishes it.

Publishing the draft is also what starts the package-store workflow (`publish-stores.yml`, trigger `release: published`). It deliberately runs *after* the release rather than inside it: both store submissions pin the URL and digest of published assets, which a draft does not serve, and a store failure can then never touch the release itself — by the time the workflow starts, the release is out. Either channel can be re-run for a tag on its own via the workflow's manual dispatch.

macOS is always built and always attached, in one of two forms (issue #66, revised by #365). With the five `MACOS_*` secrets below configured, the app is signed with a Developer ID certificate, notarised and stapled, and the release carries `flutter-gitui-v<version>-macos.zip`. Without any of them, the release instead carries `flutter-gitui-v<version>-macos-unsigned.zip`: the same build, re-signed ad-hoc without the hardened runtime (see below), plus a `README.txt` (source: `macos/README-unsigned.txt` in this directory) explaining that Gatekeeper blocks the first launch of an unsigned download — "is damaged and can't be opened" — and how to allow the app under System Settings → Privacy & Security ("Open Anyway"). The run then carries a warning annotation saying the build went out unsigned. A partially configured secret set (some of the five present) fails the macOS job outright so a typo cannot silently degrade the platform to unsigned; that check is the job's *first* step, ahead of the checkout and the build, so an owner's typo in a secret name costs seconds rather than a full macOS build. A macOS failure never blocks the Windows and Linux release.

### The hardened runtime, and why the unsigned artifact must not carry it

The unsigned form does not start on the owner's Mac — not "is damaged and can't be opened", but a process that ends (issue #421; his Mac is the only macOS this project can test on). The suspect: `flutter build macos --release` signs ad-hoc (`CODE_SIGN_IDENTITY = "-"`) while the Release configuration sets `ENABLE_HARDENED_RUNTIME = YES` (`macos/Runner.xcodeproj/project.pbxproj:633`), so the artifact carries a protection Apple documents as the companion of a real Developer ID signature on a path that has no such signature.

Two things about that protection matter here, and they are separate subsystems that are easy to conflate. The hardened runtime is `CS_RUNTIME` in the code directory, applied by AMFI at `exec` and by dyld at load time; it opts the process into library validation, restricted `DYLD_*` handling, no unsigned executable memory and no debugger attach ([Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)), and it is required by [notarisation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). Nothing in that path consults `com.apple.quarantine`, and its outcome is a dead process. Gatekeeper is the other one: quarantine-triggered, user-space, and its outcome is a dialog with an "Open Anyway" button. A user who reports a crash is describing the first mechanism; a user who reports "damaged" is describing the second.

What is *observed* is only that the download does not start. That the hardened runtime is what ends it is the leading explanation, not a verified fact — `codesign --options runtime --sign -` is a combination Apple's own tooling produces (Xcode's "Sign to Run Locally" with the capability enabled), and whether AMFI's library validation treats two *absent* team identifiers as a match cannot be settled from a Windows machine. The flag is therefore dropped on a narrower argument that holds either way: on the unsigned path it can only restrict the process and can never help it, because the one thing that requires it — notarisation — is exactly what that path does not do. Which explanation is true is then measured rather than assumed; see the launch check below.

The fix is in the workflow's `Package unsigned artifact` step: after the app is staged for packaging, it is re-signed ad-hoc *without* `--options runtime`, passing `macos/Runner/Release.entitlements` again so nothing but the runtime flag changes (App Sandbox stays off — a sandboxed process would pass its sandbox to every `git` it spawns). Re-signing was chosen over building a second time with the flag off: both paths keep sharing one set of compiled bytes, so the archive published unsigned is the same build that would have been notarised; and `flutter build macos` has no flag that forwards a build setting to `xcodebuild`, so building without the flag would mean editing `project.pbxproj` in CI — a mechanism nobody here can test, against a file Flutter rewrites on template upgrades. `ENABLE_HARDENED_RUNTIME = YES` therefore stays in the project: the signed path applies it explicitly at re-sign time anyway (`codesign --options runtime`), and a local Xcode archive still gets a notarisable configuration by default.

None of that is left as an argument. Two steps run on `macos-latest`, on the same runner that produced the artifact, against the finished `.zip` (not `build/macos/…` — packaging is itself a step that can alter a signature).

`Verify the packaged signature` unpacks the archive and asserts, naming the path it is on when it fails:

- **both**: the signature must be **valid over the packaged bytes** — `codesign --verify --deep --strict`. This is the first check and the one the rest depend on. `codesign --display` reads the signature blob and hashes nothing, so a bundle whose seal no longer matches its contents still prints a flawless `flags=…` line; [TN2206](https://developer.apple.com/library/archive/technotes/tn2206/_index.html) keeps the two apart for exactly that reason, prescribing `--verify --deep --strict` for validation and `-d` for inspection. Re-sealing a bundle is the one destructive thing the fix above does, so it is also verified immediately after the re-sign, inside `Package unsigned artifact`. What this catches that nothing else does: anything writing into the bundle after signing — a `LICENSE` copied in as the Windows and Linux legs do, a `strip`, a version stamped into the binary. A modified main executable is killed at `exec` on every Mac, a broken resource seal reads as "damaged", and neither is recoverable by the user, because "Open Anyway" cannot approve an invalid signature. `stapler validate` does not cover it either: it matches the ticket against the signature's cdhash, so an untouched signature over touched content still validates;
- **both**: a signature must be there at all — a stripped one also has no runtime flag while being unlaunchable on Apple silicon, so the unsigned path requires `Signature=adhoc` and the signed path an `Authority=Developer ID Application` line plus an `xcrun stapler validate` that accepts the extracted copy, which is what proves the notarisation ticket survived packaging;
- **unsigned**: `codesign --display` must **not** report the hardened runtime — the bit `0x10000` of the code directory flags is tested numerically, so no future flag whose name contains "runtime" can decide the gate;
- **signed**: the hardened runtime **must** be present, since Apple's notary service requires it.

`Smoke-launch the packaged app` then executes the bundle out of that same extracted archive — the end-to-end evidence a project with no Mac otherwise cannot produce. It runs two bundles. The first is the one about to ship, and it is the gate. The second is a control: the same bundle re-signed *with* `--options runtime`, i.e. the artifact exactly as issue #421 described it. Control refused and shipping copy alive means the hardened runtime is what stopped the owner's Mac and removing it is the fix; both alive means it never was the cause, and the run raises a warning saying so, because a green run that quietly means "we still do not know why the download will not start" is the failure mode this job exists to prevent.

The gate is narrow on purpose: it fires on `SIGKILL` (exit 137) or on dyld's and AMFI's code-signing refusals in the process output, and on nothing else. A headless runner has no window server, so the app may well exit non-zero, abort, or hang there; none of that is a defect in the artifact and none of it fails the step. Quarantine is deliberately not applied to the copy under test — that would test Gatekeeper's verdict, which on the unsigned path is *expected* to be a rejection and is precisely the one-time hurdle the archive's `README.txt` walks the user through.

One check is still deliberately left unasserted: `spctl --assess` is printed to the run log only, because on the unsigned path it is expected to reject and the wording of that rejection changes between macOS versions, so a verdict assertion would fail on an OS bump rather than on a defect.

## macOS signing and notarisation secrets

The workflow signs with the hardened runtime and a secure timestamp (`codesign --options runtime --timestamp`), submits to Apple with `xcrun notarytool submit --wait`, and staples the ticket with `xcrun stapler staple`. Notarisation authenticates with an App Store Connect API key rather than an Apple ID with an app-specific password: the key is not tied to any person's account or its two-factor state, can be revoked on its own, and is Apple's recommended mechanism for CI.

All five repository secrets (Settings → Secrets and variables → Actions) must be set; the signing identity itself is read off the certificate, so there is no sixth secret to keep in sync.

| Secret | Content | How to obtain |
|--------|---------|---------------|
| `MACOS_CERTIFICATE_P12` | Base64 of a **Developer ID Application** certificate with its private key (`.p12`) | Requires Apple Developer Program membership. Xcode → Settings → Accounts → Manage Certificates → "+" → Developer ID Application (only the Account Holder can create one). Export from Keychain Access as `.p12` with a password, then `base64 -i certificate.p12 \| pbcopy`. No other certificate type passes notarisation. |
| `MACOS_CERTIFICATE_PASSWORD` | The password chosen when exporting the `.p12` | Chosen at export time. |
| `MACOS_NOTARY_KEY` | Base64 of an App Store Connect API key (`.p8`) | App Store Connect → Users and Access → Integrations → Team Keys → generate a key with the **Developer** role. The `.p8` downloads exactly once; then `base64 -i AuthKey_<KEYID>.p8 \| pbcopy`. |
| `MACOS_NOTARY_KEY_ID` | The key's ID | Shown next to the key on the same page (also in the file name, `AuthKey_<KEYID>.p8`). |
| `MACOS_NOTARY_ISSUER_ID` | The team's issuer ID (a UUID) | Shown at the top of the same Integrations page. |

### The macOS update manifest, and why it carries a `signed` flag

Every release that ships a macOS archive now attaches a `latest-macos.json` beside the Windows and Linux ones (issue #387; this reverses the earlier decision recorded under #155, which rested on a client that could neither read such a manifest nor act on one). It has the same shape as the other two, plus one field they do not carry:

```json
"macos": { "fileName": "…", "fileSize": 0, "sha256": "…", "platform": "macos", "signed": false }
```

`signed` is `true` only for the archive this workflow signed with the Developer ID certificate, notarised and stapled; the ad-hoc-signed fallback published when no `MACOS_*` secret is configured is `false`. The client installs a macOS update **only** when it is `true` (`macosArchiveIsSelfInstallable`, `lib/core/services/macos_update.dart`); otherwise it names the version it found and points at the releases page.

Three reasons for gating there rather than shipping self-update unconditionally:

- Replacing a bundle the user once allowed past Gatekeeper by hand with one macOS cannot verify risks leaving them with an application that no longer opens — and the failure lands on a working installation, which is worse than the manual download it replaces.
- This project has no Mac. A self-update path for the unsigned artifact would go out untested, and the one thing an untested bundle swap must not do is destroy the installation it was meant to improve.
- With a Developer ID signature and a stapled ticket, correctness stops depending on our reasoning: macOS verifies the replacement itself.

The flag lives in the manifest rather than in the client build because it describes the bytes about to be installed, not the ones already running, and because a client already on a user's disk cannot be changed. The day the five secrets are configured, every installed macOS client starts updating itself with no client-side release needed.

Windows and Linux carry no such flag. Their installers were never gated on a signature, and adding a field nothing reads would only invite the question of why it is ignored.

A missing macOS archive skips `latest-macos.json` rather than failing the publish, because `build-macos` is allowed to fail without blocking Windows and Linux. That is exactly why the separate "Verify the macOS archive arrived" step exists: it catches a `build-macos` that reported success and still delivered nothing, which the manifest step — hard-failing only on a missing Windows or Linux archive — would let through as a green release without macOS.

## Package stores: winget and Snap

`publish-stores.yml` follows the same rule as the macOS job: a missing credential skips the publishing visibly (a warning annotation on the run names the missing secret), never fails anything, and never publishes something broken. Each store is a job of its own, so one can be re-run without the other.

**winget** fills the templates under `manifests/winget/` with the version, installer URL and SHA-256 taken from the release's own `latest-windows.json` — the URL and the digest pinned beside it therefore describe the same bytes by construction — and submits them with Microsoft's `wingetcreate submit`, which validates the manifests, forks `microsoft/winget-pkgs` under the token's account and opens the pull request. Pre-releases are skipped entirely (a notice annotation says so): winget has no channel concept, so whatever version a manifest carries is what `winget install` gives everyone. For a stable release without the token, the filled manifests are still attached to the run as the `winget-manifests` artifact, ready for a manual submission.

**Snap** downloads the published Linux archive, verifies it against the digest in `latest-linux.json`, repacks it with `manifests/snap/snapcraft.yaml` inside the `ghcr.io/canonical/snapcraft:8_core24` container, and uploads it with `snapcraft upload`. The archive's `updater` helper and `install-desktop-entry.sh` are stripped first: `$SNAP` is a read-only squashfs, so the in-app updater could never replace a file, and the desktop entry comes from snapd. A pre-release goes to the `edge` channel, a stable version to `stable` — channels are the pre-release mechanism winget lacks. The snap is always built (so a broken `snapcraft.yaml` surfaces on every release) and attached to the run as the `snap-package` artifact; only the store upload needs the credential.

| Secret | Content | How to obtain |
|--------|---------|---------------|
| `WINGET_TOKEN` | A GitHub personal access token (classic) with the `public_repo` scope | GitHub → Settings → Developer settings → Personal access tokens (classic). `wingetcreate` uses it to fork `microsoft/winget-pkgs` into the token owner's account and open the pull request from there, so it belongs to the maintainer's own account, not to a bot without winget-pkgs history. |
| `SNAPCRAFT_STORE_CREDENTIALS` | An exported Snapcraft store login | With the snap name registered (`snapcraft register flutter-gitui`, once): `snapcraft export-login --snaps=flutter-gitui --acls package_access,package_push,package_update,package_release exported.txt`, then paste the file's contents into the secret. The credential that used to sit in the local `.env` must be **rotated, not reused** (issue #283): revoke it under <https://login.ubuntu.com/> and export a fresh one for CI. |

Two things gate the *first* submission to each store, independent of CI:

- **Do not configure `WINGET_TOKEN` before issues #298/#299 are resolved.** A winget package identifier is effectively permanent: `winget-pkgs` has no rename, so publishing `FlutterGitUI.FlutterGitUI` now and renaming to gitopset under `simetrixch` later means a brand-new identifier whose users' `winget upgrade` silently stops finding versions, plus abandoned manifests whose installer URLs die with the old repository (a fresh repository gets no redirect). The workflow is ready; adding the secret after the move/rename is the entire switch-on.
- **Classic confinement needs Canonical's approval once.** The snap declares `confinement: classic` (it must run arbitrary user git and diff tools), which the Snap Store only accepts for names that were granted classic confinement after a request on the snapcraft forum. Until that grant exists, the store rejects the release step of the upload. The same consideration as winget applies to the name: the grant is per snap name, so effort spent on `flutter-gitui` is repeated for `gitopset`.

### Store installs and the in-app updater

The in-app updater polls this repository's releases and installs over the running installation. A store-managed install must update through its store instead, and today the client does not know the difference:

- **Snap:** the app files live in a read-only squashfs. The update check still sees a newer GitHub release and offers it; on accept, the download succeeds and the install then fails against the read-only filesystem. Meanwhile snapd refreshes the snap on its own schedule. The offer is a broken promise every release.
- **winget:** the zip is extracted under `%LOCALAPPDATA%\Microsoft\WinGet\Packages\...`, which is user-writable — the in-app update *succeeds*, and from then on winget's recorded version disagrees with what is on disk: `winget upgrade` will re-install its own idea of the latest version over the newer files, and `winget uninstall` complains about a modified package.

The fix belongs in the client, not in this pipeline: suppress the in-app update offer when running store-managed (the `SNAP` environment variable for snaps; an executable path under `WinGet\Packages` for winget) and point at the store instead. That is a follow-up issue against `lib/core/services/update_service.dart`.

## What is in here

| Path | Purpose |
|------|---------|
| `docker/Dockerfile.linux-base` | **Documentation, not a build input.** Pins the Flutter image so the glibc floor of a Linux build cannot drift — but nothing builds it: `ci.yml:214` and `release.yml:121` cite it in comments only, and the image they actually use is stated in the workflows. It exists so the invariant has one written home. |
| `docker/Dockerfile.linux-build` | **Documentation, not a build input**, for the same reason. It carries the `objdump` gate that fails a build requiring glibc above the core22 floor of 2.35, and that gate runs as a *step* in both workflows rather than from here. Change one and the other is now wrong, which is the cost of writing an invariant twice. |
| `manifests/snap/` | Snap packaging, consumed by `publish-stores.yml`. Declares the `core22` base that fixes the glibc floor. |
| `manifests/winget/` | winget manifest templates, filled from the published release and submitted by `publish-stores.yml`. |
| `updater/` | A small standalone program the application launches to replace its own files during an update. Built by `release.yml` and shipped inside the Windows and Linux archives; stripped from the snap, which updates through the store. |

## Not here any more

The PowerShell orchestrators that used to build and publish from a developer machine are gone; CI is the only path. Two pipelines producing the same artifact by different rules had already caused one defect, where a winget manifest paired the digest of a locally built archive with the URL of a CI-built one, under names that could never match.

`shared/update-winget-manifest.ps1`, `shared/build-snap.ps1` and `docker/Dockerfile.snap-build` followed for the same reason once `publish-stores.yml` took over the package channels (issue #283): the workflow carries the winget script's fill-from-the-published-release logic and runs the same snapcraft container the Dockerfile pointed at, so keeping the local variants would have re-created exactly the two-pipeline situation the defect came from.

`shared/changelog-generator.ps1` went last (issue #424). CI generates the changelog with `tools/changelog/generate_changelog.dart`, called twice in `release.yml` — once **before** `flutter build`, so the changelog bundled into the binary describes the build the user installed. The row that used to stand here said the opposite: *"not yet part of the tagged build, which is why the bundled changelog can trail the shipped version."* Both halves had stopped being true, and a sentence describing a limitation CI has already removed is worse than the dead file it described, because a reader distrusts something that in fact works.

The `.last-build-commit` files went with it. They were the retired pipeline's memory of what it had already built; nothing reads them now. `release/artifacts/` — that pipeline's output directory — is gone from disk too, and its `.gitignore` entry with it, along with the entries for `universal-build/`, a directory that no longer exists. An ignore rule for a path nothing produces implies the path is expected.

Icon synchronisation moved to `tools/sync-icons.ps1`, since it is a maintenance task whose output is committed like any other change rather than a step in a release.

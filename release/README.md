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

macOS is always built and always attached, in one of two forms (issue #66, revised by #365). With the five `MACOS_*` secrets below configured, the app is signed with a Developer ID certificate, notarised and stapled, and the release carries `flutter-gitui-v<version>-macos.zip`. Without any of them, the release instead carries `flutter-gitui-v<version>-macos-unsigned.zip`: the same app with only the build's ad-hoc signature, plus a `README.txt` (source: `macos/README-unsigned.txt` in this directory) explaining that Gatekeeper blocks the first launch of an unsigned download — "is damaged and can't be opened" — and how to allow the app under System Settings → Privacy & Security ("Open Anyway"). The run then carries a warning annotation saying the build went out unsigned. A partially configured secret set (some of the five present) fails the macOS job outright so a typo cannot silently degrade the platform to unsigned. A macOS failure never blocks the Windows and Linux release.

One caveat on the unsigned form has never been exercised, because this project has no Mac to test on: the Release configuration keeps `ENABLE_HARDENED_RUNTIME = YES` (`macos/Runner.xcodeproj/project.pbxproj`, required for notarisation on the signed path), so the unsigned build carries an ad-hoc signature with the hardened-runtime flag set. If a user reports that the app refuses to launch even after being allowed, that combination is the first thing to check — see issue #365.

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

### Why macOS gets no update manifest

Even when a macOS archive is published, no `latest-macos.json` is attached. This is a settled decision (issue #155), not an outstanding gap, and it follows from what the client actually does — `lib/core/services/update_service.dart`:

- `_manifestFileName` resolves a manifest name for Windows and Linux only; its fallback on every other platform is `latest.json`, which no release carries. A published `latest-macos.json` would therefore be fetched by nothing.
- `checkForUpdates` rejects any platform other than Windows and Linux outright, and `installUpdate` throws there as well. Even a correctly shaped manifest could not lead to an installed update, which is also why the macOS archive ships no `updater` helper.

So the manifest would be a file no code path reads, whose only lasting effect is to arm a half-built update flow the day somebody changes that fallback. The important part is that its absence is **not** silent: a macOS client asking for `latest.json` finds no such asset and gets a phrased error naming the releases page ("publishes no update information for this platform"), rather than the "you are up to date" that the original defect produced. macOS users update by downloading the next release.

The release workflow verifies that a `build-macos` job which reported success really did deliver exactly one archive. macOS is the only platform with no manifest to be caught by — the manifest step hard-fails on a missing Windows or Linux archive — so without that check it would be the one platform able to disappear from a green release unnoticed.

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
| `docker/Dockerfile.linux-base` | Pins the Flutter image so the glibc floor of a Linux build cannot drift. Both workflows cite it by name. |
| `docker/Dockerfile.linux-build` | Carries the `objdump` gate that fails a build requiring glibc above the core22 floor of 2.35. Mirrored as a step in both workflows. |
| `manifests/snap/` | Snap packaging, consumed by `publish-stores.yml`. Declares the `core22` base that fixes the glibc floor. |
| `manifests/winget/` | winget manifest templates, filled from the published release and submitted by `publish-stores.yml`. |
| `shared/changelog-generator.ps1` | Regenerates `assets/changelog.json`. Not yet part of the tagged build, which is why the bundled changelog can trail the shipped version. |
| `updater/` | A small standalone program the application launches to replace its own files during an update. Built by `release.yml` and shipped inside the Windows and Linux archives; stripped from the snap, which updates through the store. |

## Not here any more

The PowerShell orchestrators that used to build and publish from a developer machine are gone; CI is the only path. Two pipelines producing the same artifact by different rules had already caused one defect, where a winget manifest paired the digest of a locally built archive with the URL of a CI-built one, under names that could never match.

`shared/update-winget-manifest.ps1`, `shared/build-snap.ps1` and `docker/Dockerfile.snap-build` followed for the same reason once `publish-stores.yml` took over the package channels (issue #283): the workflow carries the winget script's fill-from-the-published-release logic and runs the same snapcraft container the Dockerfile pointed at, so keeping the local variants would have re-created exactly the two-pipeline situation the defect came from.

Icon synchronisation moved to `tools/sync-icons.ps1`, since it is a maintenance task whose output is committed like any other change rather than a step in a release.

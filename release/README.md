# Release

Releases are produced by `.github/workflows/release.yml`, triggered by pushing a tag of the form `v*.*.*`. Nothing in this directory builds or publishes the application any more; what remains is either consumed by that workflow, shipped alongside the application, or waiting for the package channels to move to CI.

## How a release happens

```bash
git tag -a v0.5.0 -m "0.5.0"
git push origin v0.5.0
```

The workflow builds Windows, Linux and macOS on their own runners, packs a flat archive per platform, derives the pre-release flag from the tag (any version containing `-` is a pre-release), writes a `latest-<platform>.json` manifest carrying the SHA-256 of the Windows and Linux archives, and opens a **draft** release with everything attached.

The draft is the gate: assets of a draft are neither served for download nor returned by the API the client polls, so nothing reaches a user until a human publishes it.

macOS is conditional. The release workflow always builds it, but attaches it to the release only when the five `MACOS_*` secrets below are configured: only then can the app be signed with a Developer ID certificate and notarised, and Gatekeeper refuses anything less with "is damaged and can't be opened" (issue #66). Without the secrets the run carries a warning annotation and the release simply ships without a macOS asset — never with one that cannot start. A partially configured secret set (some of the five present) fails the macOS job outright so a typo cannot silently drop the platform. A macOS failure never blocks the Windows and Linux release.

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

Even when a macOS archive is published, no `latest-macos.json` update manifest is attached: the in-app update flow has no macOS implementation (the client requests a manifest name only on Windows and Linux, and the archive ships no updater helper), so a manifest would advertise updates nothing can install — see issue #155.

## What is in here

| Path | Purpose |
|------|---------|
| `docker/Dockerfile.linux-base` | Pins the Flutter image so the glibc floor of a Linux build cannot drift. Both workflows cite it by name. |
| `docker/Dockerfile.linux-build` | Carries the `objdump` gate that fails a build requiring glibc above the core22 floor of 2.35. Mirrored as a step in both workflows. |
| `docker/Dockerfile.snap-build` | Snap build container. Not yet wired into CI. |
| `manifests/snap/` | Snap packaging. Declares the `core22` base that fixes the glibc floor. |
| `manifests/winget/` | winget package templates. |
| `shared/changelog-generator.ps1` | Regenerates `assets/changelog.json`. Not yet part of the tagged build, which is why the bundled changelog can trail the shipped version. |
| `shared/update-winget-manifest.ps1` | Fills a winget manifest from a **published** release: it reads the platform manifest asset for a tag and takes the file name and digest from it, so the installer URL and its hash describe the same bytes. Fails loudly on an unpublished release. |
| `shared/build-snap.ps1` | Builds the snap. Not yet wired into CI. |
| `updater/` | A small standalone program the application launches to replace its own files during an update. Not currently built by any pipeline — see issue #270. |

Moving the changelog, snap and winget steps into CI is tracked in issues #282 and #283.

## Not here any more

The PowerShell orchestrators that used to build and publish from a developer machine are gone; CI is the only path. Two pipelines producing the same artifact by different rules had already caused one defect, where a winget manifest paired the digest of a locally built archive with the URL of a CI-built one, under names that could never match.

Icon synchronisation moved to `tools/sync-icons.ps1`, since it is a maintenance task whose output is committed like any other change rather than a step in a release.

# Release

Releases are produced by `.github/workflows/release.yml`, triggered by pushing a tag of the form `v*.*.*`. Nothing in this directory builds or publishes the application any more; what remains is either consumed by that workflow, shipped alongside the application, or waiting for the package channels to move to CI.

## How a release happens

```bash
git tag -a v0.5.0 -m "0.5.0"
git push origin v0.5.0
```

The workflow builds Windows and Linux on their own runners, packs a flat archive per platform, derives the pre-release flag from the tag (any version containing `-` is a pre-release), writes a `latest-<platform>.json` manifest carrying the SHA-256 of each archive, and opens a **draft** release with everything attached.

The draft is the gate: assets of a draft are neither served for download nor returned by the API the client polls, so nothing reaches a user until a human publishes it.

macOS is deliberately absent. It builds on every commit, but is signed ad-hoc without a hardened runtime, so Gatekeeper refuses it — see issue #66.

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

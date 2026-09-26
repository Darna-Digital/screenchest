# Releasing ScreenChest

ScreenChest ships as a signed, notarized disk image on this repository's
GitHub releases, and updates itself in place through
[Sparkle](https://sparkle-project.org). One channel, no beta.

## CI and CD

| Workflow         | Trigger                                  | Does                                                                         |
| ---------------- | ---------------------------------------- | ---------------------------------------------------------------------------- |
| `mac.yml`        | pull requests, pushes to `main`          | `swift test`, then builds `ScreenChest.app` ad-hoc signed                    |
| `release.yml`    | push to `main` changing `VERSION`        | if the version is unreleased: test, build, sign, notarize, publish, redeploy the site |
| `check-www.yml`  | pull requests touching `www/`            | lint, format check, typecheck                                                |
| `deploy-www.yml` | push to `main` touching `www/`           | deploys screenchest.com                                                      |

`release.yml` reads `VERSION` and looks for a published release `vX.Y.Z`. If
there is one, the run stops in seconds. Otherwise:

1. `mac.yml` runs; a red build stops the release.
2. On a `macos-26` runner the Developer ID certificate is imported and
   `scripts/build-app.sh` builds the app, stamps `VERSION` into its
   Info.plist, and signs Sparkle and the app with the hardened runtime and a
   secure timestamp (plus `Resources/ScreenChest.entitlements`, which the
   hardened runtime needs to allow the camera and microphone).
3. `scripts/release.sh` notarizes and staples the app, wraps it in
   `ScreenChest-X.Y.Z-arm64.dmg`, then signs, notarizes and staples that too.
4. `scripts/appcast.sh` writes `appcast.xml`: the disk image, its EdDSA
   signature and the commit subjects since the previous release (website-only
   commits left out) as the notes Sparkle's update window shows.
5. `gh release create vX.Y.Z` publishes the image and the appcast as the
   latest release.
6. `deploy-www.yml` redeploys screenchest.com, whose Download button is built
   from `VERSION` and so only moves once the image exists.

A run that fails midway leaves no published release, so re-running it picks
up where it should. It can also be started by hand: **Actions → release → Run
workflow**.

## Cutting a release

1. Bump `VERSION` (plain `X.Y.Z`), commit as `Release vX.Y.Z`, push to `main`.
   Keep that push free of `www/` changes, or `deploy-www.yml` points the
   Download button at the image before it exists.
2. Watch it: `gh run watch $(gh run list -w release -L 1 --json databaseId -q '.[0].databaseId')`.

## How installed apps update

Info.plist's `SUFeedURL` is
`https://github.com/Darna-Digital/screenchest/releases/latest/download/appcast.xml`.
Sparkle checks it every six hours and on **ScreenChest → Check for Updates…**,
verifies the downloaded image against `SUPublicEDKey`, swaps the app and
relaunches.

Builds not signed with a Developer ID (`make install`, `make run`,
`scripts/watch.sh`) only check when asked, so a local build is never replaced
by the last release on its own. To try the update window against a local feed:

```bash
defaults write com.darnadigital.screenchest update.feedURL file:///tmp/appcast.xml
```

## Secrets

Set in **Settings → Secrets and variables → Actions** of `Darna-Digital/screenchest`:

| Secret                       | What                                                |
| ---------------------------- | --------------------------------------------------- |
| `APPLE_CERTIFICATE`          | base64 of the Developer ID Application `.p12`       |
| `APPLE_CERTIFICATE_PASSWORD` | that `.p12`'s password                              |
| `APPLE_API_KEY`              | base64 of the App Store Connect API key (`.p8`)     |
| `APPLE_API_KEY_ID`           | that key's ID                                       |
| `APPLE_API_ISSUER`           | that key's issuer UUID                              |
| `SPARKLE_PRIVATE_KEY`        | the EdDSA key the appcast signs the disk image with |

`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, which deploy the site,
are secrets of the `production` environment.

The Sparkle key's public half is `SUPublicEDKey` in `Resources/Info.plist`.
The private half lives in the login keychain of whoever generated it, under
the account `screenchest`. Export it into the secret with Sparkle's tools
(present under `.build` after any `swift build`):

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account screenchest -x sparkle-key.txt
gh secret set SPARKLE_PRIVATE_KEY < sparkle-key.txt && rm sparkle-key.txt
```

Losing it means installed apps refuse every later update, so keep a copy
somewhere safe.

## A notarized build on your own Mac

```bash
SIGN_IDENTITY="Developer ID Application: …" scripts/build-app.sh
SIGN_IDENTITY="Developer ID Application: …" APPLE_API_KEY_PATH=AuthKey_XXXX.p8 \
  APPLE_API_KEY_ID=XXXX APPLE_API_ISSUER=<uuid> \
  scripts/release.sh build/ScreenChest.app build/dist
```

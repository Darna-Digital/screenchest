# ScreenChest

A small, native macOS screen recorder with a built-in editor and automatic zoom — a less corporate Loom, in the spirit of Screen Studio.

- Records a display or a single window at 60 fps (ScreenCaptureKit, HEVC), plus camera, microphone and system audio, all frame-aligned on one clock.
- Tracks the cursor and clicks (no extra permissions) and generates zoom segments that follow the cursor.
- Editor: drag the clip edges to trim; right-click the zoom row to add a zoom, then drag it or its edges to move and resize it; background gradients, padding, rounded corners, shadow, camera bubble (corner, size, shape, mirror), audio levels.
- Export to MP4 (H.264 or HEVC) at source resolution or 1440p/1080p/720p. Preview and export use the same renderer, so what you see is what you get.

Requires macOS 15 or later and Xcode 16+ command line tools.

## Build and install

```bash
make install
```

Builds a release binary with SwiftPM, renders the app icon from `Resources/AppIcon/AppIcon.svg`, wraps everything in `ScreenChest.app`, signs it, replaces `/Applications/ScreenChest.app` and launches it. Rerun it whenever you want the installed app updated. `scripts/install.sh --no-launch` skips the launch; `INSTALL_DIR=~/Applications make install` installs elsewhere.

```bash
make run
```

Same build, but only into `build/ScreenChest.app`, then opens it — handy while developing. `scripts/watch.sh` does this on every save.

```bash
swift test
```

Runs the unit tests (auto-zoom, camera track smoothing, render geometry, persistence) and an integration test that renders and exports a synthetic recording through the real compositor.

The icon is a single SVG; `scripts/build-app.sh` rasterizes it with AppKit (no extra tools needed) into an `.icns` and re-renders it only when the SVG changes.

## Permissions

ScreenChest needs **Screen & System Audio Recording**, and asks for **Camera** / **Microphone** when you enable them. macOS ties the Screen Recording grant to the app's code signature. With ad-hoc signing (the default) every rebuild produces a new signature, so macOS will ask you to re-allow ScreenChest after each build.

To keep the grant across builds, create a self-signed code-signing certificate in Keychain Access (Keychain Access → Certificate Assistant → Create a Certificate…, type "Code Signing") and build with it:

```bash
make run SIGN_IDENTITY="ScreenChest Dev"
```

## Where recordings live

Each recording is a package in `~/Movies/ScreenChest/<name>.screenchest` containing `screen.mov`, `camera.mov` (if enabled), `mouse.json` and `project.json` (your edits, autosaved). Exports default to the same folder.

## Layout

```
Sources/ScreenChest/
  App/        SwiftUI app, recorder window, floating recording panel
  Capture/    ScreenCaptureKit stream, camera/mic session, asset writer, mouse tracker
  Project/    Project model, package storage, auto-zoom, zoom track
  Rendering/  Render plan, Core Image frame renderer, AVVideoCompositing, composition builder
  Editor/     Editor model, player, timeline, inspector, exporter
Tests/ScreenChestTests/
```

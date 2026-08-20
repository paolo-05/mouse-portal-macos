# MousePortal

MousePortal is a native macOS menu-bar utility that connects arbitrary segments of display edges. It lets the pointer cross gaps in a macOS display arrangement without changing that arrangement.

This repository contains an early, functional prototype. It is intentionally local-only: there is no account, networking, analytics, kernel extension, or custom driver.

## What is implemented

- Menu-bar app with no Dock icon
- Visual editor that reflects active display position, proportion, and rotation
- Portal creation by dragging from one display edge to another
- Resizable source and destination edge segments
- Bidirectional and one-way portals
- Per-portal names, colors, and enabled state
- Proportional mapping between segments of different lengths and orientations
- Pointer movement and drag continuity through a Core Graphics event tap
- Edge crossing detection that waits for the physical movement to reach the display boundary
- Configurable arrival inset, cooldown, edge threshold, velocity threshold, momentum carry, and suspend modifier
- Optional arrival indicator and animated editor preview
- Stable display UUIDs and automatic profiles for each active display combination
- Display-change recovery and event-tap re-enabling
- Local configuration persistence plus JSON import and export
- One-click settings reset that preserves portals and display profiles
- Configurable global toggle shortcut and menu-bar emergency disable
- Launch at Login through `SMAppService`
- Native multi-resolution app icon
- English diagnostics with UUIDs, coordinates, rotation, engine state, and permission state

## Requirements

- macOS 13 or later
- Apple silicon or Intel Mac supported by the selected Swift toolchain
- Xcode, or Command Line Tools whose Swift compiler and macOS SDK versions match
- Accessibility permission at runtime

An Apple Developer Program membership is **not** required to build or use the app locally. It is only needed later for a trusted Developer ID signature and notarization.

## Install with Homebrew

MousePortal can be installed from this repository as a Homebrew Cask:

```sh
brew tap paolo-05/mouse-portal-macos https://github.com/paolo-05/mouse-portal-macos.git && \
  brew install --cask paolo-05/mouse-portal-macos/mouseportal
```

Homebrew installs `MousePortal.app` in `/Applications`. To upgrade or remove it later:

```sh
brew upgrade --cask paolo-05/mouse-portal-macos/mouseportal
brew uninstall --cask mouseportal
```

Because current releases use an ad-hoc signature rather than Apple notarization, macOS may require explicit approval on first launch. Accessibility permission may also need to be enabled again after an upgrade.

## Build locally

```sh
swift test
make app
open .build/app/MousePortal.app
```

`make app` produces `.build/app/MousePortal.app` and applies an ad-hoc local signature. Use `SKIP_ADHOC_SIGNING=1 make app` to skip that step.

If Swift reports that the SDK is not supported by the compiler, update or reinstall the Command Line Tools, or select a matching Xcode installation:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

The repository now selects the matching Xcode toolchain for its Makefile commands, so the earlier standalone Command Line Tools mismatch no longer affects local builds.

## Develop with Xcode

Open [MousePortal.xcodeproj](MousePortal.xcodeproj) and select the shared `MousePortal` scheme with the `My Mac` destination.

- `⌘R` builds and runs the real menu-bar app bundle with its Info.plist and icon.
- `⌘U` runs the deterministic `MousePortalCoreTests` suite.
- The Debug and Release configurations use local ad-hoc signing, so an Apple Developer account is not required.
- Build products and test results remain inside Xcode's Derived Data. The Makefile equivalents keep them under `.build/xcode`.

The repository commands select `/Applications/Xcode.app/Contents/Developer` explicitly, even if the machine-wide `xcode-select` setting still points to Command Line Tools:

```sh
make xcode-build
make xcode-test
make xcode-open
```

To make Xcode the default toolchain for every terminal command on the Mac, optionally run this once yourself:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## First run

1. Open MousePortal. The portal editor appears on the first launch.
2. Grant Accessibility permission when prompted. If the app was rebuilt at a different path, macOS may ask again.
3. Drag from an edge of one display to an edge of another.
4. Select the portal in the sidebar to rename it, change its direction, or resize its segments.
5. Disable the existing Hammerspoon MousePortal module before testing. Running both implementations at once can cause duplicate warps.

The default global toggle is `⌃⌥⌘P`. Hold Option while crossing a portal to suspend it temporarily. Both behaviors are configurable in Settings.

## GitHub releases

The included workflows build and test every change. Releases use Conventional Commits and semantic versioning through Release Please:

- `fix:` selects the next patch version.
- `feat:` selects the next minor version.
- `feat!:` or a `BREAKING CHANGE:` footer selects the next major version.

Pushes to `main` create or update a Release PR. Merging that PR creates the `vX.Y.Z` tag and GitHub Release, then attaches the zipped app and its SHA-256 checksum. See [CONTRIBUTING.md](CONTRIBUTING.md) for the commit convention.

After publishing the archive, the release workflow updates `Casks/mouseportal.rb` with the released version and checksum.

These early archives are ad-hoc signed and not notarized. macOS Gatekeeper will not treat them like a Developer ID release. Signing and notarization can be added later without changing the app architecture.

## Architecture

- `MousePortalCore`: Codable models and deterministic portal geometry
- `PortalEngine`: short event-driven `CGEventTap` callback and cursor warping
- `DisplayService`: Core Graphics display geometry and stable UUID discovery
- `AppState`: profiles, settings, persistence, import/export, and login integration
- SwiftUI/AppKit views: menu bar, visual editor, settings, and diagnostics

The event callback performs only eligibility checks, proportional mapping, and the warp. UI feedback is dispatched separately to keep pointer latency low.

Portal crossings modify and return the original mouse event instead of dropping it. They trigger only when the current movement would physically cross the display boundary. The engine then transfers the portion of the accelerated delta beyond that boundary, preserving the feel of a continuous gesture and uninterrupted drags.

## Known prototype limits

- The global shortcut editor currently supports one alphanumeric key plus modifiers.
- GitHub artifacts are not Developer ID signed or notarized.
- Full VoiceOver coverage is a quality goal, not yet a certified conformance target.
- Hardware behavior still needs validation across a larger matrix of mice, trackpads, high-polling devices, rotated displays, and macOS versions.

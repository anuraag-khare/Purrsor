# AGENTS.md

## Project

- Name: `Purrsor`
- Type: native macOS desktop pet built with `Swift 6` and `AppKit`
- Scope: local desktop overlay app only
- Non-goals: cloud services, accounts, AI integrations, or third-party app integrations

## Working Agreement

- Preserve the macOS-first, native `AppKit` approach.
- Keep the app lightweight and local-first.
- Do not add web stacks or cross-platform abstractions unless explicitly requested.
- Prefer narrow, incremental changes over broad architectural rewrites.
- Respect unrelated user changes in the worktree.

## Repository Layout

- `project.yml`: XcodeGen project definition for the app target
- `Purrsor.xcodeproj`: generated Xcode project
- `Config/Info.plist`: app bundle metadata used by Xcode builds
- `Sources/DesktopPetApp/App`: application lifecycle and wiring
- `Sources/DesktopPetApp/Overlay`: floating panel, rendering, and interaction behavior
- `Sources/DesktopPetApp/Input`: global keyboard monitoring and typing intensity tracking
- `Sources/DesktopPetApp/Behavior`: pet state behavior logic
- `Sources/DesktopPetApp/Motion`: movement and animation logic
- `Sources/DesktopPetApp/Models`: shared state and value types
- `Sources/DesktopPetApp/Preferences`: settings and preferences UI/state
- `Sources/DesktopPetApp/Status`: menu bar status item behavior
- `Sources/DesktopPetApp/Support`: persistence and permission helpers
- `Sources/DesktopPetApp/Resources`: bundled assets
- `docs/architecture.md`: product boundary and module notes
- `scripts/`: local build and asset helper scripts

## Build And Run

- Generate Xcode project: `xcodegen generate`
- Open Xcode project: `open Purrsor.xcodeproj`
- Build a local app bundle: `./scripts/build-app.sh`
- Build a dev app bundle for testing: `./scripts/dev-bundle-app.sh`
- Build the Xcode app into stable DerivedData: `./scripts/dev-build-xcode-app.sh`

## Validation

- Start with an Xcode build through `./scripts/dev-build-xcode-app.sh` or the `Purrsor` scheme in Xcode.
- Prefer validating overlay, input monitoring, permissions, and bundle resource behavior through a real `.app` bundle.
- When project settings change, regenerate the Xcode project with `xcodegen generate` if available.
- Use Xcode as the preferred path for app-level debugging and behavior verification in this environment.

## macOS Constraints

- Full Xcode is available in this environment.
- Global keyboard monitoring requires Accessibility permission.
- Permission-sensitive behavior is more reliable when tested as a real `.app` bundle.
- The app is unsigned or ad hoc signed for local use; do not assume notarization or production release automation exists.
- Preserve bundle identifiers and signing settings unless the task explicitly requires changing them.

## Implementation Guidance

- Keep features aligned with the desktop pet product boundary in `README.md` and `docs/architecture.md`.
- Prefer AppKit-native solutions for overlay windows, hit testing, menu bar behavior, and system input monitoring.
- Keep dependencies minimal and justified.
- Update docs when architecture, setup, build, signing, or run workflows change.

## Scripts

- `scripts/build-app.sh`: produces a standalone app bundle
- `scripts/dev-bundle-app.sh`: packages a dev app bundle for local testing
- `scripts/dev-build-xcode-app.sh`: builds the Xcode target to a stable output path
- `scripts/extract_v2_cat_sheet.py`: sprite extraction helper
- `scripts/normalize_sprites.py`: sprite normalization helper

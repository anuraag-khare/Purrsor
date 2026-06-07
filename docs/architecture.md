# Architecture

## Product boundary

`Purrsor` is an independent desktop pet. It does not integrate with AI agents, editors, or external apps. The only system-wide signal in the MVP is keyboard activity.

## Module map

### `App`

Owns lifecycle and wiring:

- bootstraps AppKit
- creates the overlay window
- creates the status item
- starts keyboard monitoring
- persists simple settings

### `Overlay`

Owns all on-screen pet behavior:

- transparent floating panel
- visibility and click-through state
- current cat visual state
- placeholder drawing today, sprite renderer later

### `Input`

Owns raw input and interpretation:

- `GlobalKeyMonitor`: receives `keyDown` events
- `TypingIntensityTracker`: converts key events into moods

### `Models`

Shared value types:

- app settings
- cat mood and visual state

### `Status`

Menu bar utility shell:

- show or hide overlay
- toggle click-through
- request accessibility access
- quit app

### `Support`

Cross-cutting helpers:

- settings persistence
- accessibility permission prompt
- launch-at-login registration

## Recommended next implementation order

1. Replace placeholder cat drawing with sprite sheet playback.
2. Add proper hover and drag interactions to the overlay.
3. Add idle timer and random idle animations.
4. Add reminder scheduling and notification bubbles.
5. Add preferences window.
6. Improve signing and packaging around the existing Xcode app target.

## Why AppKit, not Tauri

For this product, the primary technical risk is not settings UI. It is native windowing and input behavior:

- transparent overlay on all spaces
- non-activating utility behavior
- click-through toggling
- system keyboard observation

AppKit is the lowest-friction way to solve those directly.

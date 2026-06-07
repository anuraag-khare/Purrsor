# Architecture

## Overview

Purrsor is a native macOS desktop pet built with AppKit. The app runs as a lightweight menu bar utility with a transparent floating overlay, local settings persistence, and system-wide keyboard activity monitoring.

The architecture is intentionally simple:

- AppKit owns the application lifecycle and windowing
- a floating overlay window renders the cat and handles direct interaction
- keyboard activity feeds behavior state changes
- a preferences window and menu bar item control local app settings
- all state is stored locally in a small JSON settings file

## Runtime Structure

At launch, the app:

1. Loads persisted settings
2. Creates the floating overlay window
3. Creates the menu bar status item
4. Creates the preferences window controller
5. Starts keyboard monitoring
6. Starts behavior and motion controllers
7. Applies current settings to the overlay and supporting services

The app does not depend on any backend, network service, account system, or external integration.

## Module Layout

### `App`

Coordinates startup and top-level wiring.

Responsibilities:

- bootstraps AppKit
- loads and saves settings
- wires overlay, preferences, status item, and behavior systems together
- applies setting changes across the app

### `Overlay`

Owns the on-screen pet.

Responsibilities:

- hosts the transparent floating panel
- renders sprite states and text overlays
- handles direct mouse interaction such as petting and drag-to-reposition
- tracks cursor position for eye movement

Key types:

- `OverlayWindowController`
- `CatOverlayView`
- `CatSpriteCatalog`

### `Input`

Converts raw system input into behavior signals.

Responsibilities:

- monitors global keyboard activity
- calculates typing intensity over time

Key types:

- `GlobalKeyMonitor`
- `TypingIntensityTracker`

### `Behavior`

Maps input and context into cat mood/state changes.

Responsibilities:

- drives mood transitions such as idle, typing, petting, sleepy, and reminding
- reacts to hover, drag, and petting signals
- manages reminder and sleep timing

Key type:

- `PetBehaviorController`

### `Motion`

Controls autonomous movement behavior for the overlay.

Responsibilities:

- manages wandering movement when enabled
- suspends movement during interactions or state-specific animations
- keeps movement aligned with the overlay’s current frame and home position

Key type:

- `PetMotionController`

### `Preferences`

Owns the settings UI.

Responsibilities:

- presents current settings
- emits user-driven updates through callbacks
- reflects runtime service state such as Accessibility or launch-at-login status

Key types:

- `PreferencesWindowController`
- `PreferencesViewController`

### `Status`

Owns the menu bar entry point.

Responsibilities:

- exposes quick actions for preferences, overlay visibility, and click-through
- shows app presence in the macOS menu bar

Key type:

- `StatusItemController`

### `Models`

Contains shared app state and value types.

Responsibilities:

- stores persisted settings
- represents cat visual and motion state
- defines UI-facing option sets and defaults

### `Support`

Holds cross-cutting helpers.

Responsibilities:

- settings persistence
- resource lookup
- Accessibility permission checks
- launch-at-login registration

## Data Flow

The main runtime loop is:

1. `GlobalKeyMonitor` captures keyboard events
2. `TypingIntensityTracker` derives a typing signal
3. `PetBehaviorController` updates the current cat mood/state
4. `OverlayWindowController` renders the resulting visual state
5. `PetMotionController` adjusts overlay position when wandering is active

Settings changes flow the other direction:

1. Preferences or menu bar actions change a setting
2. `AppDelegate` updates the in-memory `AppSettings`
3. dependent controllers are updated immediately
4. `SettingsStore` persists the new JSON state to disk

## Persistence

User settings are stored locally as JSON under the user Application Support directory.

Persisted settings include:

- overlay position
- overlay visibility
- click-through mode
- wandering enabled state
- reminder timing
- sleep timing
- launch-at-login preference
- text and indicator presentation settings
- overlay scale

## Platform Constraints

Purrsor relies on macOS-specific behavior that directly shapes the architecture:

- global keyboard monitoring requires Accessibility permission
- the overlay uses a non-standard transparent floating window
- launch-at-login is implemented with macOS system services
- unsigned or ad hoc signed builds may need permissions to be re-granted after rebuilds

Because of those constraints, validating behavior through a real `.app` bundle is more reliable than testing only through isolated source-level execution.

## Design Principles

- Keep the app local-first and offline
- Prefer native AppKit behavior over abstraction layers
- Keep state flow explicit and easy to trace
- Favor small modules with narrow responsibilities
- Minimize dependencies and hidden runtime complexity

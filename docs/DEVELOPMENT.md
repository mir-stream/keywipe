# Development

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/KeyWipe` | App lifecycle, permission flow, overlays, and SwiftUI/AppKit views |
| `Sources/KeyWipeCore` | Input filtering, hold detection, release state, and cursor association |
| `Tests/KeyWipeCoreTests` | Unit tests that do not enable global input filtering |
| `Resources/Info.plist` | App identity, version, and minimum macOS version |
| `scripts/build.sh` | Release build, icon generation, app packaging, and certificate signing |
| `scripts/verify-event-tap.sh` | Tagged synthetic event pipeline checks |
| `scripts/verify-interaction.sh` | Native-window click/scroll delivery check |

Open `Package.swift` in Xcode or work with the Swift command-line tools. No external Swift packages are required.

## Input handling

Keyboard mode uses an active session event tap. It drops key-down, key-up, modifier, and system-defined events. Pointer events pass through with keyboard modifiers removed, so holding Command or Control does not alter the finish-button click.

Trackpad mode uses an active HID event tap with an all-events mask. Esc is consumed like other keys; its timestamps drive the three-second confirmation. A failed HID tap prevents the session from starting rather than silently falling back to a later tap.

Event suppression and cursor movement are separate concerns. `CursorMotionLock` uses `CGAssociateMouseAndMouseCursorPosition(false)` while KeyWipe is foreground, then reconnects on finish, interruption, or shutdown. A failed freeze cancels the session; a failed restore retains its state so shutdown or reactivation can retry.

The event tap and UI timers run on the main run loop. Callbacks do no file I/O or logging. A tap timeout or permission loss ends the session rather than leaving a protected-state overlay on screen. Hold durations use monotonic time and do not depend on keyboard repeat settings. Finishing waits for pressed keys/buttons and recent pointer activity to clear.

## Routine checks

```sh
swift test
swift build -c release
```

The unit suite covers hold thresholds, early release, drag cancellation, repeat handling, Esc consumption, pointer/gesture filtering, pressed-input draining, and balanced cursor freeze/restore calls. The cursor unit tests inject a fake association function; they do not freeze the developer's cursor.

GitHub Actions runs unit tests and a release executable build. It does not package or sign an app, request privacy permissions, or run the interactive probes.

## Local integration checks

Run these from a terminal that already has Accessibility permission, with KeyWipe out of cleaning mode:

```sh
bash scripts/verify-event-tap.sh
bash scripts/verify-interaction.sh
```

The event-tap probe filters only synthetic events with a unique marker. A downstream sink discards test events before applications can receive them. It verifies delivery, blocking, restoration, and a real three-second Esc hold. Physical keyboard and pointer events are passed through unchanged.

The interaction probe briefly opens a native window and sends synthetic clicks and scrolls to it. It checks that the view receives input before filtering, receives no additional input while filtering, and receives input again afterward. It also calls the real cursor disassociation and restoration APIs. It restores the prior cursor position and foreground application when done.

These probes validate synthetic event paths. They do not replace checks with a physical keyboard/trackpad or establish compatibility with every system gesture.

## App diagnostics and UI previews

After packaging the app:

```sh
dist/KeyWipe.app/Contents/MacOS/KeyWipe --diagnostics
dist/KeyWipe.app/Contents/MacOS/KeyWipe --render-previews dist/previews
```

Neither command enables input filtering. Preview rendering creates app-only PNGs without taking a screenshot of the desktop.

Launching an executable from a terminal can attribute privacy permissions to that terminal. To inspect the installed app's own permission state, launch diagnostics through LaunchServices:

```sh
open -n -W -g --stdout "$PWD/dist/diagnostics.txt" \
  "$PWD/dist/KeyWipe.app" --args --diagnostics
cat dist/diagnostics.txt
```

## Signing and updates

Keep the same certificate identity and bundle identifier across updates. Do not replace certificate signing with `codesign --sign -`: an ad-hoc designated requirement depends on that build's hash and can leave a stale Accessibility entry after the executable changes.

The build script selects a single available Apple Development identity or accepts `KEYWIPE_SIGNING_IDENTITY`. Signing keys and certificates stay in the developer's keychain; they are not repository assets or CI secrets. Builds are for local development and are not notarized distribution packages.

Quit the running app before replacing its bundle. After a deliberate signing-identity change, remove the old Accessibility entry and grant the current app permission again.

## Device validation

- Keyboard mode: built-in and external keys are ignored, and the trackpad can finish with a two-second hold.
- Trackpad mode: cursor motion, clicking, scrolling, and nearby keyboard input are blocked; a short Esc press cancels, and a three-second hold followed by release finishes.
- Check pinch, swipe, Spaces, and Mission Control gestures on the target macOS version.
- Verify that held keys or buttons do not leak into the next app on release.
- Check multiple displays, display reconfiguration, sleep/wake, app exit, and permission loss.

Both cleaning modes have been exercised on an Apple Silicon Mac. Hardware actions such as power and Touch ID remain outside the supported scope.

## References

- Apple: [Event taps](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)) and [filter callbacks](https://developer.apple.com/documentation/coregraphics/cgeventtapcallback).
- Apple: [Trackpad events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html).
- Apple: [Controlling the mouse cursor](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html).
- Apple: [Code signing requirements and app identity](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).

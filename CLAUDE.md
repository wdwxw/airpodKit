# AirPodKit — dev notes

macOS menu bar utility that remaps the three buttons on Apple's **wired**
EarPods/AirPods remote (Volume Up, center/Play-Pause, Volume Down) to
custom keyboard shortcuts. SwiftUI + AppKit, macOS 13+, no App Sandbox,
signed with a local dev certificate (not Developer ID yet — see Signing
below). Original design/plan lives at
`~/.claude/plans/stateful-dancing-nest.md` if it still exists on this
machine; treat this file as the up-to-date source of truth instead.

## Build & run

```
./build.sh          # regenerates AirPodKit.xcodeproj via xcodegen, builds, copies to ./build/AirPodKit.app
./build.sh --run    # same, then kills any running instance and relaunches
```

`AirPodKit.xcodeproj` is generated from `project.yml` by `xcodegen` (`brew
install xcodegen`) — it is gitignored, never hand-edit it, edit
`project.yml` instead. Source files are added automatically since
`project.yml` just globs the `AirPodKit/` directory.

`./build/AirPodKit.app` is the stable, fixed path the app always builds
to. Don't move it — see Signing/TCC below for why the path matters.

## Architecture

```
AirPodKitApp (SwiftUI @main)
  └─ MenuBarExtra(.window) → PopoverRootView   (the UI, menu bar popover)
  └─ AppDelegate (NSApplicationDelegate)        (real onboarding window, see below)

RemapEngine.start()  — called once from AirPodKitApp.init()
  ├─ wires RemoteButtonMonitor.onButtonPress → looks up ShortcutStore →
  │    KeystrokeSynthesizer.post(...) if mapped, else lets the event through
  └─ subscribes to PermissionsManager's published grant state and
       starts/stops RemoteButtonMonitor's CGEventTap accordingly (not just
       once at launch — see "Permission flow" below, this is the thing
       that was actually broken and fixed twice)

RemoteButtonMonitor  — the CGEventTap. Owns the tap lifecycle + health check.
KeystrokeSynthesizer — posts synthetic CGEvents for the configured shortcut.
Shortcut / ModifierKey — the data model (see below).
ShortcutStore        — Codable JSON in UserDefaults, ObservableObject.
PermissionsManager   — polls + requests Accessibility / Input Monitoring.
LaunchAtLoginManager — thin wrapper over SMAppService.mainApp.
```

### How button presses are captured

Wired remote buttons surface on macOS as the same private event stream
used for keyboard media keys: `NSEvent.systemDefined` (type 14, aka
`NX_SYSDEFINED`), `subtype == 8` (`NX_SUBTYPE_AUX_CONTROL_BUTTONS`), with
the key code and down/up state packed into `data1`:
- high 16 bits = key type: `NX_KEYTYPE_SOUND_UP=0`, `NX_KEYTYPE_SOUND_DOWN=1`,
  `NX_KEYTYPE_PLAY=16` (center button — mapped to Play/Pause's key type)
- bits 8–15 = state: `0x0A` = down, `0x0B` = up

`RemoteButtonMonitor` installs a `CGEventTap` at `kCGHIDEventTap` with
`kCGEventTapOptionDefault` (an active/consuming tap, not listen-only),
decodes this, and if `ShortcutStore` has a mapping for that button, returns
`nil` from the callback (swallows the event, so the system doesn't change
volume / trigger play-pause) and posts a synthetic replacement keystroke.
If unmapped, the event is returned unmodified (`Unmanaged.passUnretained`,
**not** `passRetained` — the callback doesn't own a retain on the event it's
handed, this was a real bug once, see git history) so default behavior
happens.

⚠️ **This mechanism was never empirically confirmed against real hardware.**
The original plan (Milestone 0) called for a throwaway diagnostic spike
(`Spike/main.swift` — still present, unbuilt binary gitignored) to log real
`data1` values from the user's actual wired remote before writing the real
engine, specifically because third-party USB-C/Lightning dongles can
surface differently. We built the CLI, got Accessibility/Input Monitoring
permission working, but never actually captured a real button press in the
log during that session — development moved on to the full app under time
pressure before this was confirmed. **If button remapping doesn't work at
all, this is the first thing to re-check**: rebuild and run
`Spike/main.swift` (`swiftc -o spike main.swift -framework
ApplicationServices -framework IOKit -framework Cocoa`), watch its log
output while pressing the real buttons, and confirm the key types match
what `RemoteButtonMonitor` expects. If they don't, the fallback (per the
original plan) is raw `IOHIDManager` device-level capture on HID usage page
0x0C instead of the `NSSystemDefined` translation layer.

### Shortcut model (`Shortcut.swift`, `ModifierKey.swift`)

Two shapes, both need to be supported end-to-end (recording, storage,
synthesis, display) whenever touching this:

```swift
enum Shortcut {
    case modifierOnly(ModifierKey)                        // e.g. just tap right ⌥
    case combo(modifiers: Set<ModifierKey>, keyCode: CGKeyCode)  // e.g. ⌘⇧S, or bare Return
}
```

`ModifierKey` has 8 cases — left/right distinguished for all four modifiers
(`leftCommand`/`rightCommand`/etc). This distinction is **not** available
from `NSEvent.modifierFlags` (device-independent, collapses both sides into
one bit) — it comes from reading the actual `keyCode` off a `flagsChanged`
event (`kVK_Command` vs `kVK_RightCommand`, etc, all in
`Carbon.HIToolbox`). `ShortcutRecorderField.swift`'s `RecorderNSView` is
where this is captured: it overrides both `keyDown` (base keys) and
`flagsChanged` (modifiers), tracking which modifiers were pressed *at some
point* during the recording session (not "currently held" — a solo tap
that's released still counts) plus a 1s commit-debounce so a slow ⌘ then V
still lands as one combo instead of firing on the first keystroke.

Regular function/arrow keys (Return/Delete/Escape/arrows/F-keys) don't need
special recorder handling — they arrive as normal `keyDown` events and are
named via `KeyCodeNames.swift`'s `special` dictionary; anything else falls
through to `UCKeyTranslate` for a live keyboard-layout-aware character.

### Permission flow (this broke twice already — read before touching)

`PermissionsManager` polls `AXIsProcessTrusted()` +
`IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)` every 2s (timer added to
`.common` run loop mode, not `.default` — matters because `.default` mode
pauses while a menu/alert tracking loop is active) and publishes both via
`@Published`. Two consumers:

1. **`RemapEngine`** subscribes via Combine (`combineLatest` + `map`, **no
   `.removeDuplicates()`** — that was the first bug: dedup meant the
   `sink` only fired once on the false→true transition and never retried,
   so a tap that failed to create at that exact moment stayed dead
   forever) and calls `RemoteButtonMonitor.shared.start()` /`.stop()` to
   match. `start()` itself is safe to call repeatedly: it checks
   `CGEvent.tapIsEnabled` and rebuilds if the existing tap died instead of
   just checking `eventTap == nil`.
2. **`AppDelegate`** shows a real `NSWindow` (not just relying on the menu
   bar popover, which the user can easily never notice — `LSUIElement`
   apps have no Dock icon and SwiftUI's `MenuBarExtra` has no public API to
   open its popover programmatically) with `PermissionsOnboardingView`
   whenever not both granted, on every launch, auto-closing once granted.

If you're debugging "permission granted but nothing happens," check in
this order: (a) is `RemoteButtonMonitor.eventTap` actually non-nil and
`CGEvent.tapIsEnabled` true — add a temporary print in `checkTapHealth()`;
(b) is the running binary actually the one that was just rebuilt (stale
process from before a signing-identity change looks identical from the
Dock/menu bar); (c) is it signed with the stable local identity, not
ad-hoc — see Signing below.

## Signing / TCC persistence

Ad-hoc signing (`codesign --sign -`) produces a different identity every
build, so macOS forgets the Accessibility/Input Monitoring grant on every
rebuild during development — this was a real, confusing dead end early on.
Fixed by `scripts/ensure_dev_cert.sh`, which creates (idempotently) a
self-signed, locally-trusted code signing certificate named `AirPodKit
Dev` in the login keychain, and `project.yml` signs with
`CODE_SIGN_IDENTITY: "AirPodKit Dev"` instead of `"-"`. As long as the
bundle identifier (`com.airpodkit.app`) and this signing identity stay the
same, permission grants survive rebuilds. `build.sh` always runs the cert
script first (no-op if it already exists).

This local cert is **not** suitable for distribution — it's dev-only, self
signed, untrusted by anyone else's machine. Before shipping to the user
for real use outside this dev loop, switch to a real Developer ID
Application certificate + notarization (the original plan's Milestone 1
packaging step, not yet done). `ENABLE_HARDENED_RUNTIME` is currently
`NO`; that needs to flip to `YES` for notarization too.

## Known gaps / not yet done

- Milestone 0 hardware validation never actually completed (see above) —
  the whole remap mechanism rests on an assumption that hasn't been
  double-checked against this user's actual hardware.
- No Developer ID signing / notarization — current signing is dev-only
  local trust, fine for iterating on this machine, not for distributing
  the app elsewhere.
- No automated tests. The originally planned XCTest-able pieces
  (`ShortcutStore` JSON round-trip, `Shortcut.displayString` formatting,
  `NX_KEYTYPE_*` decoding) were never written.
- No app icon / proper `Assets.xcassets` — menu bar icon is just
  `Image(systemName: "airpods")`.
- Center-button multi-click semantics (double/triple click, long-press
  Siri) are explicitly out of scope — only a single press → one fixed
  shortcut is supported.

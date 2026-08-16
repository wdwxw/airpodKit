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
NowPlayingClaim      — claims MPRemoteCommandCenter/MPNowPlayingInfoCenter
                        so macOS doesn't auto-launch Music.app (see below).
DebugLog             — appends timestamped lines to
                        ~/Library/Logs/AirPodKit/airpodkit.log; use this to
                        debug button handling instead of stdout prints,
                        since the app usually has no attached terminal.
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

⚠️ **Must consume both the down AND up half of a mapped press, not just
down.** Each physical press generates two `NX_SYSDEFINED` events (down
then up). Originally only the down event was inspected/consumed and the
up event was unconditionally passed through — the center button mapped to
a shortcut fired the shortcut correctly on down, but the untouched up
event still reached the system and triggered Play/Pause anyway, since
macOS's default handling for that key type acts on the up transition. Fix:
`RemoteButtonMonitor.onButtonPress` is now called for *both* halves
(signature is `(RemoteButton, isDown: Bool) -> Bool`) and consumes both
when mapped; `RemapEngine` only calls `KeystrokeSynthesizer.post` on the
`isDown == true` call, to avoid firing the shortcut twice per press.

✅ **Confirmed working against the user's real wired remote.** The
throwaway diagnostic spike (`Spike/main.swift`, still present, unbuilt
binary gitignored) never actually captured a press during its own test
session, so the mechanism went unverified for a while — but combo
shortcuts (modifier + base key) have since been confirmed end-to-end on
real hardware: pressing the physical button fires the mapped shortcut and
the original volume/play-pause action is suppressed. If a *future* piece
of hardware (different cable/dongle) doesn't work, this is still the
first thing to re-check: rebuild and run `Spike/main.swift` (`swiftc -o
spike main.swift -framework ApplicationServices -framework IOKit
-framework Cocoa`), watch its log output while pressing the buttons, and
confirm the key types match what `RemoteButtonMonitor` expects. If they
don't, the fallback (per the original plan) is raw `IOHIDManager`
device-level capture on HID usage page 0x0C instead of the
`NSSystemDefined` translation layer.

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
`RecorderNSView` also overrides `performKeyEquivalent(with:)` while
recording and forwards straight into `keyDown` — Return/Tab/Escape are
otherwise liable to get intercepted by the window (e.g. for a default
button) before ever reaching `keyDown`.

⚠️ **`.modifierOnly` synthesis gotcha, already hit once:** a modifier
key's own press/release is delivered as `flagsChanged`, not
`keyDown`/`keyUp` — the *only* signal of "which modifier, and whether
held or released" is the event's `flags` field itself. `KeystrokeSynthesizer`
used to post `flags: []` on both the down and up event for a lone
modifier, which is indistinguishable from "nothing pressed" — a total
no-op the user correctly reported as "single modifier shortcuts do
nothing." Fixed: the down event now carries `[modifier.comboFlag]`, the
up event carries `[]`. A `.combo`'s base key is different — both its down
and up events legitimately carry the *same* modifier flags throughout,
since they're just reporting what was held during that keystroke rather
than changing modifier state themselves. Don't "simplify" these back to
sharing one code path.

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

### The "consumed the event but Music.app still launches" trap

Consuming the `NX_SYSDEFINED` event (both down and up, correctly) is
**not enough** to stop the center button from launching Music.app. macOS
has a separate fallback: if a Play/Pause-type key is pressed and nothing
has claimed "Now Playing" status, it auto-launches the system default
media app. That fallback does not go through the `NX_SYSDEFINED` stream
our `CGEventTap` observes at all, so no amount of correctly consuming the
tap's event will stop it — confirmed by `DebugLog` output showing every
down/up correctly logged as `consumed` while Music still launched.

First attempt (`NowPlayingClaim.swift`, called once from
`RemapEngine.start()`): register a no-op `MPRemoteCommandCenter`
play/pause/toggle handler and publish minimal
`MPNowPlayingInfoCenter.default().nowPlayingInfo`, hoping AirPodKit would
become the "Now Playing" target macOS routes the key to. **This alone did
not fix it.** Unified log around a real press showed the actual chain:

```
mediaremoted: Destination app com.apple.Music not available for command
<...TogglePlayPause..., SenderBundleIdentifier = <com.apple.rcd>, ...>,
and command requested a launch.
```

`com.apple.rcd` (Remote Control Daemon) parses the raw hardware report
and sends the `TogglePlayPause` command straight to `mediaremoted` —
`AirPodKit`'s own log confirms the `MPRemoteCommandCenter` registration
did register (`canBeNowPlayingApplication=YES`), but `mediaremoted`'s
(undocumented) arbitration for "who gets this command" still picked Music
anyway. Being *eligible* isn't the same as *winning* — there's no public
API to force the win.

Actual fix (`MusicLaunchGuard.swift`, also started from
`RemapEngine.start()`): pragmatic and a bit blunt, but it's what actually
works — observe `NSWorkspace.didLaunchApplicationNotification`, and if
`com.apple.Music` launches within 2s of `RemapEngine` having just handled
a mapped press (`MusicLaunchGuard.noteMappedPressHandled()` records the
timestamp), `forceTerminate()` it immediately. Verified with the
`fake_media_key` spike (fire a simulated press, manually `open -a Music`
within the window, confirm it dies within ~1s). Keep `NowPlayingClaim`
too — no reason to remove it, it's harmless and might help on some macOS
versions/configurations even if it didn't here.

If a similar "we consumed it but X still happened" bug shows up again for
some other system behavior, don't assume the fix must live in
`RemoteButtonMonitor`/the CGEventTap — check the unified log
(`log show --predicate 'process == "AirPodKit"'` and also
`process == "mediaremoted"` etc.) for what's *actually* generating the
unwanted behavior before touching code. This is now the second time it's
been a separate system mechanism entirely: first the
menu-bar-icon-not-showing dead end below, now this.

## "Menu bar icon doesn't show up" — usually not our bug

This has happened before and cost real time chasing the wrong thing: the
app runs fine, `NSApp`/System Events accessibility queries even report a
menu bar item existing, but no icon is visible on screen at all — not the
SF Symbol, not a plain text/emoji label, nothing. Root cause turned out to
be the user's actual menu bar being completely full of *other* apps'
status items; macOS drops new status items silently with zero error/log
output when there's no room, rather than showing an overflow indicator.
`NSStatusItem`/`MenuBarExtra` from *any* app (tested with a bare
`NSStatusItem` outside SwiftUI entirely) fail to render the same way in
that state, so if this recurs: rule out MenuBarExtra/SwiftUI bugs
immediately by testing with a minimal raw AppKit `NSStatusItem` script,
and check whether the user's menu bar has free space (ask them to quit a
couple of other menu bar apps) before spending more time in the code.

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

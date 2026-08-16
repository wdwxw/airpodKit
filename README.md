# AirPodKit

A macOS menu bar utility that remaps the three buttons on Apple's **wired**
EarPods / AirPods-style remote — Volume Up, the center button, and Volume
Down — into custom keyboard shortcuts.

<p align="center">
  <em>音量加 → 中间键 → 音量减，和真实线控上的物理排列一致</em>
</p>

## Features

- Remap **Volume Up**, the **center button**, and **Volume Down** to any
  keyboard shortcut, individually.
- Shortcuts can be a full combo (⌘⇧S, Return, ⌥→, ...) **or a single
  modifier key by itself** (just ⌘, just ⌥, ...).
- Left and right modifier keys are treated as distinct and labeled
  explicitly (e.g. "左⌘" vs "右⌘") — left ⌘ and right ⌘ can be mapped to
  different things.
- Lives entirely in the menu bar — no Dock icon, no main window.
- Launch at login, powered by `SMAppService` (no separate helper app).
- Guides you through granting the two required macOS permissions
  (Accessibility, Input Monitoring) automatically on launch until both are
  granted.

## How it works, in short

Volume/media buttons on Apple's wired remotes surface through the same
private system event stream macOS uses for keyboard media keys.
AirPodKit installs a low-level event tap to detect those presses; if
you've mapped a button, it blocks the original action (so your system
volume doesn't jump) and sends your custom shortcut instead. Unmapped
buttons behave exactly as before.

Because of this, AirPodKit needs two permissions to work:

- **Accessibility** — to intercept and replace the button press.
- **Input Monitoring** — to see the button press at all.

The app will prompt you for both the first time you open it, and again on
future launches if either hasn't been granted yet.

## Requirements

- macOS 13 Ventura or later
- Apple wired EarPods / AirPods-style remote (Lightning, USB-C, or via the
  3.5mm adapter)

## Building from source

```bash
brew install xcodegen   # one-time
git clone <this repo>
cd airPodKit
./build.sh --run
```

This builds the app to `./build/AirPodKit.app` and launches it. See
`CLAUDE.md` for architecture details if you want to dig into the code.

## Status

This is an actively developed personal utility, not yet notarized or
signed for distribution outside this project's own build process. Grab
the source and build it yourself for now.

# CrispMac design

CrispMac makes external non-Retina displays look sharp on Apple Silicon Macs by running them in
HiDPI modes: the desktop is drawn at 2× the size it "looks like" and scaled down to the panel.
On a 2560×1440 monitor, "looks like 2048×1152" is drawn at 4096×2304. This replaces the one
BetterDisplay feature the author used.

Personal tool, published in case it helps others: MIT licensed, works with any external
display, macOS 14+, built from source with the Swift command line tools (no Xcode), no
updater, no release builds, not notarized.

## What macOS offers

macOS already lists some HiDPI modes for many external displays. On the reference setup
(M1 Max, ASUS VG27AQ3A 2560×1440 @ 144 Hz, macOS 26) those are 2048×1152 @ 144 Hz and
1280×720 and below. BetterDisplay's "High Resolution" on that machine is simply selecting
one of these existing modes; it installs nothing. v1 does the same with public CoreGraphics
APIs, so 144 Hz, 10-bit and HDR are untouched and no admin rights are needed.

`CrispMac --list` prints what each external display offers.

## Behaviour (v1)

**Layout**
- Menu bar icon (SF Symbol `display`) opens a panel with one section per external display:
  HiDPI switch, resolution slider, refresh rate picker; plus "Open Settings…" and "Quit".
- Settings window: display picker, the same three controls, launch at login, the reset
  shortcut hint. The Dock icon shows only while this window is open. Re-opening the app
  (double-click in Finder) opens it, which matters when macOS hides the menu bar icon.
- The built-in display is never touched.

**Controls**
- The slider's stops are every available size with the panel's aspect ratio. It snaps to them
  and applies on release; the readout updates while dragging. Dots under the slider mark
  sizes that have a sharp (HiDPI) version.
- HiDPI is a wish kept separately from the size. At a size with no sharp version the switch
  greys out ("Not available at this size") and the normal mode is used; returning to a sharp
  size turns HiDPI back on.
- The refresh rate picker lists only rates that exist for the current size and HiDPI state.
  Changing size keeps the rate when possible, otherwise picks the highest.

**Persistence**
- Settings are saved per display, keyed by the system display UUID (derived from vendor,
  model and serial). Two connected displays with the same key get their port appended.
- Saved settings are re-applied at launch, 2 s after wake, and after any display
  reconfiguration (plug, unplug, mode change by another app), only when the mode drifted.
- If a saved size or rate is unavailable (other port, bandwidth-limited dock, OS update),
  the closest size with the same HiDPI wish and the saved or highest rate is used, a note is
  shown, and the saved choice is kept so it comes back when available.
- Launch at login (SMAppService) is on by default: the first launch turns it on.

**Safety**
- Every change shows "Keep this display setting?" centred on the changed display with a
  10-second countdown; running out reverts. Changing another display confirms the pending
  change first. Quitting reverts any unconfirmed change.
- ⌃⌥⌘0 (a Carbon hot key, no Accessibility permission) resets every external display to
  native size, HiDPI off, highest refresh rate, and saves that.

## Code map

- `Sources/CrispCore`: pure decision logic with no CoreGraphics types, unit tested.
  `ModeCatalog` (slider stops, sharp sizes, rates, resolving a setting to a mode, fallbacks),
  `DisplayKey` (settings keys), `SettingsStore`.
- `Sources/CrispMac`: the app. `DisplayService` is the only CoreGraphics caller.
  `DisplayController` owns state, applies changes, runs the revert flow and re-applies saved
  settings. The rest is UI: status item, settings window, revert prompt, hot key, login item.

## Next: more sharp sizes (v2)

Goal: HiDPI at 21 sizes, 16:9, 64 px apart, 1280×720 to 2560×1440, in sharp and normal versions,
without ever rebooting.

Mechanism, the same one BetterDisplay uses for "flexible scaling":
1. Write a `scale-resolutions` display override to
   `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<hex>/DisplayProductID-<hex>`,
   backing up any existing file. This is the only privileged step: a one-off macOS admin
   password prompt, no background helper.
2. Make macOS re-read it without a reboot: add a temporary `CGVirtualDisplay` so the Mac is
   never left without a display, disable and re-enable each external display with
   `CGSConfigureDisplayEnabled` inside a display configuration transaction, wait for them to
   come back online, remove the virtual display. Screens go blank for about 2–4 s; the app
   warns and asks first, every time.
3. The new sizes are then ordinary modes: the v1 slider picks them up and switches instantly.

Decisions:
- "Add more sharp sizes" / "Remove extra sizes" buttons in the settings window; removal deletes
  the override and restores the backup.
- The override applies to every display of the same vendor and model.
- If macOS forgets the sizes after sleep or replug (seen on Sonoma), show a menu bar badge and
  a "Reload sizes" button. Never blank the screens without being asked.

Before building v2, test on the reference setup (BetterDisplay quit): install the override,
re-detect, and check that the new sizes run at 144 Hz with 10-bit and HDR. If they only come
out at 60 Hz, stop and reconsider.

Not chosen: mirroring to a virtual display (about double the WindowServer load, cursor capped
at the virtual display's rate, shaky HDR, app must keep running) and virtual EDID injection
(unproven to add HiDPI sizes, lost on reboot).

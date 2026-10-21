# CrispMac design

CrispMac makes external non-Retina displays look sharp on Apple Silicon Macs by running them in
HiDPI modes: the desktop is drawn at 2× the size it "looks like" and scaled down to the panel.
On a 2560×1440 monitor, "looks like 2048×1152" is drawn at 4096×2304. This replaces the one
BetterDisplay feature the author used.

Personal tool, published in case it helps others: MIT licensed, works with any external
display, macOS 14+, built from source with the Swift command line tools (no Xcode), no
updater, no release builds, not notarized.

## What macOS offers, and why CrispMac adds sizes

On its own, macOS offers few HiDPI modes for a 1440p monitor. On the reference setup
(M1 Max, ASUS VG27AQ3A 2560×1440 @ 144 Hz, macOS 26.3) that is 1280×720 and below: far too
big to be useful. A sharp 2048×1152 @ 144 Hz was listed while BetterDisplay had put the display
in it, but it disappeared from the mode list as soon as the display left that mode, and it never
came back after a reconnect. CrispMac therefore installs its own sizes; v1's "use only what
macOS offers" turned out to leave the user stuck.

`CrispMac --list` prints what each external display offers and whether the extra sizes are
installed and loaded.

## Extra sizes: how it works

1. **Override file.** CrispMac writes
   `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<hex>/DisplayProductID-<hex>`,
   which macOS reads whenever the display connects. Its `scale-resolutions` entries become
   ordinary display modes. CrispMac adds the native aspect ratio, 64 pt apart in width, from half
   the native width to native: 21 sizes on a 1440p monitor (1280×720 … 2560×1440).
   - Entries use Apple's 12-byte format (as in Apple's own overrides in
     `/System/Library/Displays`): big-endian pixel width, pixel height, flags. Flag 1 = HiDPI
     drawn at those pixels (2× the looks-like size); flag 0 = normal mode. The 16-byte format
     with `0x200000` used by older Intel-era tools is ignored on Apple Silicon.
   - Every size gets both entries so HiDPI can be switched off at any size. Flag-0 entries also
     produce half-size HiDPI by-products (e.g. 1248×702); the slider hides sizes under half the
     native width, so they never show.
   - 2560×1440 HiDPI (5120×2880 backing) is not offered by macOS; native stays normal-only.
   - The file carries a `CrispMacOverride` key. CrispMac only ever removes files with it. An
     existing override from another tool is backed up to
     `/Library/Application Support/CrispMac/Backups/` and restored on removal.
   - Applies to every display of that vendor and model.
2. **Admin rights.** Install and remove run a short shell script through
   `do shell script … with administrator privileges`: the standard macOS password prompt,
   once per action. No privileged helper is installed.
3. **Loading without a reboot.** CrispMac disables and re-enables the displays of that model
   with the private `CGSConfigureDisplayEnabled` inside a session-scoped display configuration,
   waits 2 s between, then waits up to 10 s for them to come back. macOS re-reads the override,
   like a replug. Screens go black for 2–4 s, so the app asks first, every time. Session scope
   means logging out restores the displays if anything goes wrong.
   - It refuses when no other display would stay on (e.g. lid closed) and asks for a physical
     replug instead. A temporary `CGVirtualDisplay`, as BetterDisplay uses, would avoid that but
     needs more private API; not worth it for now.
4. **If macOS forgets the sizes** (seen on Sonoma after sleep or replug): when an installed
   override's sizes are mostly missing from the mode list, the menu bar icon gets a warning
   badge and a "Reload Sizes" button appears. CrispMac never blanks screens unasked.

Verified on the reference setup: all 20 new HiDPI sizes and their normal versions at
144/120/100/60 Hz; switching to them keeps 144 Hz and the same colour depth and EDR headroom as
native; the modes persist after switching away; removal + reload restores macOS's own list.

## Behaviour

**Layout**
- Menu bar icon (SF Symbol `display`) opens a panel with one section per external display:
  HiDPI switch, resolution slider, refresh rate picker, a reload warning when needed; plus
  "Open Settings…" and "Quit".
- Settings window: display picker, the same three controls, the extra sizes section
  (Add More Sharp Sizes / Remove Extra Sizes / Reload Sizes), launch at login, the reset
  shortcut hint. The Dock icon shows only while this window is open. Re-opening the app
  (double-click in Finder) opens it, which matters when macOS hides the menu bar icon.
- The built-in display is never touched.

**Controls**
- The slider's stops are every available size with the panel's aspect ratio, from half the
  native width. It snaps to them and applies on release; the readout updates while dragging.
  Dots under the slider mark sizes that have a sharp (HiDPI) version.
- HiDPI is a wish kept separately from the size. The switch only works at sizes that exist both
  sharp and normal; elsewhere it shows "Not available at this size" or "Always on at this size".
  Returning to a size with both turns HiDPI back to the wish.
- The refresh rate picker lists only rates that exist for the current size and HiDPI state.
  Changing size keeps the rate when possible, otherwise picks the highest.

**Persistence**
- Settings are saved per display, keyed by the system display UUID (derived from vendor,
  model and serial). Two connected displays with the same key get their port appended.
- Saved settings are re-applied at launch, 2 s after wake, and after any display
  reconfiguration (plug, unplug, mode change by another app), only when the mode drifted.
- If a saved size or rate is unavailable (other port, bandwidth-limited dock, forgotten extra
  sizes), the closest size with the same HiDPI wish and the saved or highest rate is used, a note
  is shown, and the saved choice is kept so it comes back when available.
- Launch at login (SMAppService) is on by default: the first launch turns it on.

**Safety**
- Every change shows "Keep this display setting?" centred on the changed display with a
  10-second countdown; running out reverts. Changing another display, or reloading displays,
  confirms the pending change first. Quitting reverts any unconfirmed change.
- ⌃⌥⌘0 (a Carbon hot key, no Accessibility permission) resets every external display to
  native size, HiDPI off, highest refresh rate, and saves that.

## Code map

- `Sources/CrispCore`: pure decision logic with no CoreGraphics types, unit tested.
  `ModeCatalog` (slider stops, sharp/normal versions, rates, resolving a setting to a mode,
  fallbacks), `DisplayOverride` (override path, sizes, entry encoding, loaded check),
  `DisplayKey` (settings keys), `SettingsStore`.
- `Sources/CrispMac`: the app. `DisplayService` is the only public-CoreGraphics caller;
  `DisplayReloader` holds the private display off/on; `OverrideInstaller` writes and removes
  the override with admin rights. `DisplayController` owns state, applies changes, runs the
  revert flow and re-applies saved settings. The rest is UI.
- `--print-install-command` / `--print-remove-command` print the exact root scripts the
  buttons run, and `--reload` runs the display reload, for testing with `sudo`.

## Not chosen

- Mirroring to a virtual display: about double the WindowServer load, cursor capped at the
  virtual display's rate, shaky HDR, app must keep running.
- Virtual EDID injection: unproven to add HiDPI sizes, lost on reboot.
- Rebooting to load overrides: ruled out by the user.

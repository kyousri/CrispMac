# CrispMac

Make external monitors look sharp on Apple Silicon Macs.

On a non-Retina external display such as a 27" 1440p monitor, macOS draws everything at 1×
and text looks soft. CrispMac switches the display to a **HiDPI** mode: the desktop is drawn
at twice the size it looks like, then scaled down to the panel. "Looks like 2048 × 1152" on a
2560 × 1440 monitor is drawn at 4096 × 2304, and everything gets noticeably crisper.

That's all it does:

- **HiDPI** on or off
- **Resolution** slider (dots mark the sizes with a sharp version)
- **Refresh rate** picker, so you keep 144 Hz
- Settings per monitor, re-applied at login, on wake and when you plug in
- "Keep this display setting?" after every change, reverting by itself after 10 seconds
- **⌃⌥⌘0** resets every external display to its native resolution, even if you can't see anything

It lives in the menu bar and has a small settings window.

## Requirements

- Apple Silicon Mac, macOS 14 or later
- Swift command line tools (`xcode-select --install`); Xcode is not required

## Build and install

```sh
./scripts/build-app.sh
cp -R build/CrispMac.app /Applications/
open /Applications/CrispMac.app
```

Move the app to `/Applications` before the first launch: the first launch turns on launch at
login for wherever the app is.

The app is signed ad hoc and not notarized. It runs fine on the Mac that built it. A copy
from another Mac needs right-click → **Open** the first time.

If you also run BetterDisplay or a similar tool, quit it: two apps changing display modes
will fight each other.

## Where's the icon?

macOS 26 hides menu bar icons that don't fit, especially next to the notch. If you don't see
CrispMac, allow it in **System Settings → Menu Bar**, or open the app again from Finder to
get the settings window.

## Which sizes are sharp?

CrispMac offers the HiDPI modes macOS itself lists for your display. On a 2560 × 1440 monitor
that's typically 2048 × 1152 and 1280 × 720 and below. To see what your display offers:

```sh
build/CrispMac.app/Contents/MacOS/CrispMac --list
```

Adding more sharp sizes without a reboot is planned; see [docs/design.md](docs/design.md).

## Development

```sh
./scripts/test.sh                  # unit tests (Swift Testing)
./scripts/build-app.sh debug       # debug build of the app
```

The display logic lives in `Sources/CrispCore` and is tested without touching real displays.
`Sources/CrispMac` is the app. See [docs/design.md](docs/design.md) for how it works and why.

## Caveats

CrispMac v1 only uses public macOS APIs. The planned extra-sizes feature will rely on
undocumented ones, which a macOS update can break. It's a personal tool shared as is.

## License

MIT

# Interstellar — Forerunner 955 / Solar

A clean Connect IQ watch-face foundation for a 260 × 260 MIP display.

## Included

- centered 12/24-hour time
- date and battery readouts
- restrained cardinal accents
- real `SensorHistory.getPressureHistory()` data path
- gracefully flat graph when the simulator has no pressure history
- centralized layout and palette constants
- custom-font loading hook
- low-power-safe minute updates

## Build

```sh
chmod +x build.sh run.sh
./build.sh
./run.sh
```

The scripts automatically select the newest directory under:

```text
~/.Garmin/ConnectIQ/Sdks/
```

Overrides are available:

```sh
CONNECTIQ_SDK=/path/to/sdk \
CONNECTIQ_KEY=/path/to/developer_key \
./build.sh fr955
```

## Simulator pressure data

The simulator commonly begins with no stored pressure history. Use its
**Simulation** or **Data** menus to provide sensor/history data. Until then,
the bottom graph intentionally appears as a thin horizontal placeholder.

## Custom time font

1. Generate or obtain a Connect IQ-compatible `.fnt`.
2. Put it at `resources/fonts/time_digits.fnt`.
3. Uncomment `TimeDigits` in `resources/fonts/fonts.xml`.
4. In `InterstellarView.onLayout()`, replace the built-in font assignment
   with:

```monkeyc
_timeFont = WatchUi.loadResource(Rez.Fonts.TimeDigits);
```

The digit filter keeps only `0123456789:` to reduce memory use.

## Main editing points

- `source/Theme.mc` — colors, spacing and graph dimensions
- `drawMinuteAccents()` — future fading triangular arms
- `drawTime()` — typography and placement
- `drawPressureGraph()` — visual style and pressure scaling

The manifest targets Garmin's `fr955` device profile, shared by the
Forerunner 955 and 955 Solar.

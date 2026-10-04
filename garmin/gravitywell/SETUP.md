
# Garmin Numeral Watch Face

GravityWell analog watch face for the Garmin Forerunner 955, developed
in Monkey C using the Garmin Connect IQ SDK.

The design uses custom 12/4/8 numerals, a circular hour-tick band
and a minimalist white dial.

## 1. Project directory

Enter the project directory:

```bash
cd ~/stow/garmin/numeral
```

The project contains the following principal files:

| File | Purpose |
|------|---------|
| manifest.xml | Application metadata and supported devices |
| monkey.jungle | Build configuration |
| source/GravityWellView.mc | Watch-face view |
| source/FaceGeometry.mc | Dial geometry |
| source/DialRenderer.mc | Numerals and dial rendering |
| build.sh | Build script |
| bin/minimal.prg | Compiled application |

Actual filenames may differ slightly.

## 2. Build the watch face

From the project directory:

```bash
./build.sh
```

Alternatively, compile directly using the Connect IQ compiler:

```bash
mkdir -p bin

monkeyc \
   -f monkey.jungle \
   -d fr955 \
   -o bin/minimal.prg \
   -y ~/.Garmin/ConnectIQ/Keys/developer_key.der
```

Compiler arguments:

- `-f` — Project configuration file.
- `-d` — Target device (Forerunner 955).
- `-o` — Compiled application output.
- `-y` — Developer signing key.

The build should report `BUILD SUCCESSFUL`.

## 3. Launch the simulator

Start the Connect IQ simulator if it is not already running:

```bash
podman run --rm -it \
   --name garmin-ciq-sim \
   --network=host \
   --security-opt label=disable \
   -e DISPLAY="$DISPLAY" \
   -e XAUTHORITY=/tmp/.Xauthority \
   -v /tmp/.X11-unix:/tmp/.X11-unix \
   -v "${XAUTHORITY:-$HOME/.Xauthority}:/tmp/.Xauthority:ro" \
   -v "$HOME/.Garmin/ConnectIQ:/root/.Garmin/ConnectIQ" \
   localhost/garmin-ciq-sim:latest \
   /root/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/simulator

Load the compiled application:

```bash
monkeydo "$(pwd)/bin/gravitywell.prg" fr955
```

The simulator can remain open between builds.

After changing the source code, rebuild and relaunch the application.

## 4. SDK configuration

The previously installed SDK was:

```text
~/.Garmin/ConnectIQ/Sdks/
   connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2
```

Verify that the SDK tools are accessible:

```bash
command -v monkeyc
command -v monkeydo
command -v connectiq
```

If any command is missing, inspect the SDK installation and
your shell PATH.

The developer signing key was previously located at:

```text
~/.Garmin/ConnectIQ/Keys/developer_key.der
```

Keep the signing key private and maintain a backup.

## 5. Clean build

IMPORTANT: During initial development, the project was copied
from `gravitywell-face` into the new `numeral` directory.

An old compiled application can cause the simulator to display
an earlier version of the watch face even when the source code
has changed.

To ensure the correct application is running:

```bash
cd ~/stow/garmin/numeral

rm -f bin/minimal.prg

./build.sh

ls -lh bin/minimal.prg

monkeydo "$(pwd)/bin/minimal.prg" fr955
```

Always launch the compiled application using its absolute path.

If the build succeeds but changes are not visible, inspect
`build.sh` for references to the original project directory
or a different output filename.

## 6. Simulator on Void Linux

The Garmin Connect IQ simulator previously encountered missing
legacy WebKit and libsoup dependencies on Void Linux.

The workaround was to run the simulator in a compatible
container environment.

If the existing container and wrapper script are still
available, use those rather than reinstalling the SDK.

The container must have access to the Garmin SDK and the
project's compiled application.

The `connectiq`, `monkeyc` and `monkeydo` commands above assume
that the SDK tools or their corresponding wrappers are available
in the current shell.

## 7. Normal development workflow

### Step 1: Edit

Open the project in Kakoune and modify the appropriate Monkey C
source files.

Principal rendering components:

- GravityWellView.mc — Watch-face view.
- FaceGeometry.mc — Dial geometry and positioning.
- DialRenderer.mc — Numeral and tick rendering.

### Step 2: Compile

```bash
./build.sh
```

### Step 3: Launch

```bash
monkeydo "$(pwd)/bin/minimal.prg" fr955
```

### Step 4: Inspect

Examine the watch face in the FR955 simulator.

Check numeral placement, tick positions, alignment and
the overall visual balance of the dial.

### Step 5: Repeat

Adjust the geometry or rendering code, rebuild and relaunch.

## 8. Quick build and launch

For routine development, the complete sequence is:

```bash
cd ~/stow/garmin/numeral

./build.sh &&
   monkeydo "$(pwd)/bin/minimal.prg" fr955
```

For a clean build:

```bash
cd ~/stow/garmin/numeral

rm -f bin/minimal.prg

./build.sh &&
   monkeydo "$(pwd)/bin/minimal.prg" fr955
```

## 9. Current development status

The last successful simulator run displayed:

- Custom 12, 4 and 8 numerals.
- A white MIP-style background.
- A circular band of small hour ticks.
- The intended minimalist dial layout.

The custom numerals were rendering correctly.

The next development task is to refine the radial placement
of the numerals relative to the hour-tick band.

Begin with small positional adjustments, without changing
the numeral size.

The 12 numeral provides a useful reference for judging
the relationship between the numeral glyph metrics and
the tick circle.

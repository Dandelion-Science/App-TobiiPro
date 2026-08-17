# TobiiPro Connector

This app connects to a Tobii Pro device to the LabRecorder.

Users of the Tobii Glasses 3 should check [here](https://github.com/tobiipro/Tobii.Glasses3.SDK/releases) for an official application from Tobii.

## Dependencies

It requires you to get the [TobiiPro C SDK](https://www.tobiipro.com/product-listing/tobii-pro-sdk/#Download) and
make sure your use case is covered by the end user agreement.
Extract the C SDK folder (e.g. `Linux/64` for 64 bit Linux) here and rename it
to `tobii` or set the `TOBIIPRO_ROOT_DIR` variable to its path

## Building

On Linux, the `Makefile` wraps the CMake invocation:

```bash
make deps                                     # cmake, ninja, gcc-c++, Qt6, libGL
make                                          # configure + build into ./build
sudo make install-system PREFIX=/opt/tobii-lsl TOBII_SDK_ROOT=/opt/tobii-sdk
make help                                     # all targets and variables
```

`install` puts `TobiiPro` and `tobiifinder` in `$PREFIX/bin` and `TobiiPro.cfg`,
the logo and the licence in `$PREFIX/share/TobiiPro`; `install-system` adds the
`.desktop` entry and icon under `/usr` (`DESKTOP_PREFIX`). liblsl and the Tobii
SDK are not installed by `make deps` — see the comments at the top of the
Makefile. `make` is a convenience, not a requirement: the CMake project still
builds directly, following the general
[LSL Application build instructions](https://labstreaminglayer.readthedocs.io/dev/app_build.html).

`TobiiPro.cfg` is read and rewritten relative to the working directory, so a
launcher has to `cd` into the data directory first. The installed `.desktop`
entry does this with `Path=`.

### The SDK is not bundled

`BUNDLE_SDK` defaults to `OFF`: `libtobii_research.so` is not copied into the
install tree, and `TOBII_SDK_ROOT/lib` is baked in as an RPATH instead. This app
is GPLv3 and the SDK is proprietary, so the two must not be distributed together
— and the RPATH guarantees the app loads the SDK build it was compiled against.
A different build (Eye Tracker Manager ships one) loads fine, enumerates
trackers, then streams gaze compressed toward the screen centre. To tell them
apart, look at each screen corner: gaze should span roughly 0.0–1.0 on both axes.

### Changes from upstream

Upstream is unmaintained. Besides the Qt6 migration and the fixes to the
declared sampling rate and model metadata (see the git history), liblsl's
`installLSLApp` / `installLSLAuxFiles` / `LSLGenerateCPackConfig` are gone — all
three are deprecated in liblsl 1.17 — replaced by plain `install()` rules.
`cpack` is no longer configured, so package the staged tree instead:

```bash
make install DESTDIR=/tmp/stage PREFIX=/opt/tobii-lsl
tar czf tobii-lsl.tar.gz -C /tmp/stage/opt/tobii-lsl .
```

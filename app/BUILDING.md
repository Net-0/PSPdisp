# Building the PSPdisp Windows application

The app is Windows-only. It can be cross-built from Linux, but the Pascal
half needs a Free Pascal cross toolchain that Arch does not package — see
[Known gaps](#known-gaps) before starting.

## Packages

```sh
# Pascal compiler, sources (Lazarus needs them) and the LCL + lazbuild
sudo pacman -S fpc fpc-src lazarus

# Cross-compiler for the two C/C++ DLLs
sudo pacman -S mingw-w64-gcc
```

### SpeexDSP

`loopback.dll` needs the Speex resampler, and there is no mingw build of it
in the Arch repos. The host `speexdsp` package is ELF and cannot be linked
into a PE, so it has to be cross-built once:

```sh
curl -LO https://downloads.xiph.org/releases/speex/speexdsp-1.2.1.tar.gz
tar xf speexdsp-1.2.1.tar.gz && cd speexdsp-1.2.1
./configure --host=i686-w64-mingw32 --prefix=$PWD/../speexdsp-mingw \
            --disable-shared --enable-static
make && make install
```

Then build with:

```sh
make dlls SPEEXDSP_PREFIX=/path/to/speexdsp-mingw
```

Installing it into `/usr/i686-w64-mingw32` instead lets you drop the
variable, but keeping it out of the sysroot avoids clashing with any future
package.

## Layout

| Target | Source | Produces |
|---|---|---|
| `make dlls` | `source/wusb/`, `source/loopback/` | `build/wusb.dll`, `build/loopback.dll` |
| `make app` | `source/PSPdisp.lpi` | `build/PSPdisp.exe` |
| `make` | both | all three |

Default target architecture is 32-bit (`ARCH=i686`), matching the original
0.6.1 release. `make ARCH=x86_64` builds 64-bit.

## One-time setup

### 1. Convert the Delphi project

`PSPdisp.dpr` is a Delphi VCL project. Lazarus uses LCL, so it must be
converted once:

> Lazarus → Tools → Convert Delphi Project to Lazarus Project → `source/PSPdisp.dpr`

This writes `source/PSPdisp.lpi` and turns `main.dfm` into `main.lfm`. The
Makefile builds from those and never re-runs the conversion.

The form has ~250 components and every one is a standard control with a
direct LCL equivalent, so the conversion is mostly mechanical. Two things
need hand-fixing afterwards:

- **`TXPManifest` / the `XPMan` unit** has no LCL counterpart. Delete the
  component and the `uses` entry; Lazarus applies a manifest via
  Project Options → Application → "Use manifest file to enable themes".
- `{$R *.DFM}` in `main.pas` becomes `{$R *.lfm}`.

### 2. Add `extern "C"` to loopback

`audio.pas` resolves two entry points by their **MSVC C++ mangled** names:

```pascal
InitializeLoopbackRecordingImport = '?InitializeLoopbackRecording@@YAHIIP6AXPAXI@Z@Z';
StopLoopbackRecordingImport       = '?StopLoopbackRecording@@YAHXZ';
```

GCC mangles to the Itanium ABI instead, so those symbols would not exist in a
mingw-built DLL. `source/loopback/loopback.def` re-exports them under the
MSVC spellings, but that only works if the two functions have undecorated
internal names. In `source/loopback/main.cpp`, change:

```cpp
DllExport int StopLoopbackRecording()
DllExport int InitializeLoopbackRecording(unsigned int sampleRate, ...)
```

to

```cpp
extern "C" DllExport int StopLoopbackRecording()
extern "C" DllExport int InitializeLoopbackRecording(unsigned int sampleRate, ...)
```

This keeps `audio.pas` unchanged, so the DLL stays drop-in compatible with
the original release.

## Known gaps

**The `app` target will not cross-build out of the box.** `lazbuild
--os=win32` needs an FPC cross-compiler *and* an LCL built for the win32
widgetset. Arch's `fpc`/`lazarus` ship host units only. Options:

1. Build `PSPdisp.exe` natively — run Lazarus on Windows against the same
   `.lpi`. Simplest, and the DLLs can still be cross-built from Linux.
2. Build an FPC cross toolchain (`make CROSSINSTALL` with
   `OS_TARGET=win32 CPU_TARGET=i386`), then recompile the LCL for win32.

`make dlls` has no such problem and works from Linux once the packages above
are installed.

**`winusb.h`** ships with recent mingw-w64 but is absent from older ones. If
`wusb.dll` fails to compile on that header, the declarations it needs are
small enough to vendor.

## Not covered here

`driver/` and `sideshow/` are kernel/UMDF drivers built with the Windows
Vista WDK's `build` system. They have no open-toolchain path, and the driver
models they target (XDDM, Windows SideShow) were removed in Windows 8.

#
#  ***************************************************
#  PSPdisp - Windows host application
#
#  Cross-build from Linux with Free Pascal / Lazarus
#  and mingw-w64.  See BUILDING.md for prerequisites.
#  ***************************************************
#

# --- Target ---------------------------------------------------------------
# The original release is 32-bit; the display driver and the Delphi app were
# both x86.  Override with `make ARCH=x86_64` if you know what you are doing.
ARCH       ?= i686
MINGW      ?= $(ARCH)-w64-mingw32
FPC_CPU    ?= i386

BUILD      ?= build
SRC        := source

CC         := $(MINGW)-gcc
CXX        := $(MINGW)-g++
WINDRES    := $(MINGW)-windres
LAZBUILD   ?= lazbuild

CFLAGS     := -O2 -Wall
DLLFLAGS   := -shared -static-libgcc

# SpeexDSP is not packaged for mingw on Arch.  Point this at a cross-built
# copy (see BUILDING.md); leave empty if it is installed into the mingw
# sysroot directly.
SPEEXDSP_PREFIX ?=
ifneq ($(SPEEXDSP_PREFIX),)
SPEEX_CFLAGS  := -I$(SPEEXDSP_PREFIX)/include
SPEEX_LDFLAGS := -L$(SPEEXDSP_PREFIX)/lib
endif

# --- Components -----------------------------------------------------------
WUSB_DLL      := $(BUILD)/wusb.dll
LOOPBACK_DLL  := $(BUILD)/loopback.dll
APP_EXE       := $(BUILD)/PSPdisp.exe

.PHONY: all dlls app clean
all: dlls app

dlls: $(WUSB_DLL) $(LOOPBACK_DLL)
app:  $(APP_EXE)

$(BUILD):
	@mkdir -p $(BUILD)

# --- wusb.dll -------------------------------------------------------------
# WinUsb + SetupAPI wrapper.  Plain C with cdecl __declspec(dllexport)
# functions, so mingw emits the undecorated names usb.pas expects.
$(WUSB_DLL): $(SRC)/wusb/main.c $(SRC)/wusb/wusb.rc | $(BUILD)
	$(WINDRES) $(SRC)/wusb/wusb.rc -O coff -o $(BUILD)/wusb.res.o
	$(CC) $(CFLAGS) $(DLLFLAGS) -o $@ $< $(BUILD)/wusb.res.o \
		-lsetupapi -lwinusb -lole32

# --- loopback.dll ---------------------------------------------------------
# WASAPI loopback capture (Vista/7) with a Speex resampler.
#
# audio.pas resolves these two entry points by their *MSVC* C++ mangled
# names.  GCC mangles differently, so loopback.def re-exports them under the
# names the Delphi side asks for.  This requires the two functions to be
# declared extern "C" in main.cpp -- see BUILDING.md.
$(LOOPBACK_DLL): $(SRC)/loopback/main.cpp $(SRC)/loopback/loopback.rc \
                 $(SRC)/loopback/loopback.def | $(BUILD)
	$(WINDRES) $(SRC)/loopback/loopback.rc -O coff -o $(BUILD)/loopback.res.o
	$(CXX) $(CFLAGS) $(SPEEX_CFLAGS) $(DLLFLAGS) -o $@ $< $(BUILD)/loopback.res.o \
		$(SRC)/loopback/loopback.def $(SPEEX_LDFLAGS) \
		-lole32 -loleaut32 -lwinmm -lspeexdsp

# --- PSPdisp.exe ----------------------------------------------------------
# Delphi VCL project converted to Lazarus/LCL.  PSPdisp.lpi and main.lfm are
# produced once by the Lazarus IDE ("Tools > Convert Delphi Project"); this
# rule only rebuilds from them.
$(APP_EXE): $(SRC)/PSPdisp.lpi | $(BUILD)
	$(LAZBUILD) --build-mode=Release \
		--cpu=$(FPC_CPU) --os=win32 --ws=win32 \
		--build-ide= \
		-o $@ $<

$(SRC)/PSPdisp.lpi:
	@echo "ERROR: $@ does not exist yet."
	@echo "Open $(SRC)/PSPdisp.dpr in Lazarus and run"
	@echo "  Tools > Convert Delphi Project to Lazarus Project"
	@echo "See BUILDING.md."
	@false

clean:
	-rm -rf $(BUILD)
	-rm -f $(SRC)/*.o $(SRC)/*.ppu $(SRC)/*.compiled

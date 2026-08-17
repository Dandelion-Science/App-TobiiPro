# TobiiPro (tobii-lsl) build and install helper.
#
#   make deps                 install build dependencies (dnf / apt)
#   make                      configure and build into ./build
#   make install              install to $(PREFIX)
#   sudo make install-system  install + launcher entry and icon
#   make uninstall            remove what the last install placed
#   make help                 list all targets and variables
#
# `make deps` covers neither liblsl (not packaged by any distro) nor the Tobii
# Pro C SDK (proprietary): point LSL_INSTALL_ROOT and TOBII_SDK_ROOT at them.
# TOBII_SDK_ROOT holds include/ and lib/, and is baked into the binary as an
# RPATH, so it loads that build with no environment set up — though a
# DT_RUNPATH is searched after LD_LIBRARY_PATH, which can still override it.

PREFIX           ?= /usr/local
DESTDIR          ?=
BUILD_DIR        ?= build
# RelWithDebInfo: a crash on an acquisition machine should come back as a stack
# trace rather than a list of package names.
BUILD_TYPE       ?= RelWithDebInfo
LSL_INSTALL_ROOT ?= /usr/local
TOBII_SDK_ROOT   ?= /opt/tobii-sdk
DESKTOP_PREFIX   ?= /usr
EXEC_PATH        ?= $(PREFIX)/bin/TobiiPro
JOBS             ?= $(shell nproc 2>/dev/null || echo 4)

GENERATOR ?= $(shell command -v ninja >/dev/null 2>&1 && echo Ninja || echo "Unix Makefiles")

# Off: the SDK is proprietary and GPLv3 forbids conveying it with a GPL binary.
BUNDLE_SDK ?= OFF

CMAKE_FLAGS = \
	-G "$(GENERATOR)" \
	-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
	-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
	-DCMAKE_PREFIX_PATH=$(LSL_INSTALL_ROOT) \
	-DLSL_INSTALL_ROOT=$(LSL_INSTALL_ROOT) \
	-DTOBIIPRO_ROOT_DIR=$(TOBII_SDK_ROOT) \
	-DTOBIIPRO_BUNDLE_SDK=$(BUNDLE_SDK)

SYSTEM_FLAGS = \
	-DTOBIIPRO_DESKTOP_INTEGRATION=ON \
	-DTOBIIPRO_DESKTOP_PREFIX=$(DESKTOP_PREFIX) \
	-DTOBIIPRO_EXEC_PATH=$(EXEC_PATH)

# cmake --install reads DESTDIR from the environment.
export DESTDIR

.PHONY: all configure build install install-system post-install uninstall clean distclean deps help
.NOTPARALLEL:

all: build

configure:
	cmake -S . -B $(BUILD_DIR) $(CMAKE_FLAGS) $(CMAKE_EXTRA)

build: configure
	cmake --build $(BUILD_DIR) --parallel $(JOBS)

# Both targets set the flag, so switching between them is not defeated by the
# value left in CMakeCache.txt.
install: CMAKE_EXTRA += -DTOBIIPRO_DESKTOP_INTEGRATION=OFF
install: build
	cmake --install $(BUILD_DIR)
	@echo "Installed to $(DESTDIR)$(PREFIX)"

install-system: CMAKE_EXTRA += $(SYSTEM_FLAGS)
install-system: build
	cmake --install $(BUILD_DIR)
	@$(MAKE) --no-print-directory post-install
	@echo "Installed to $(DESTDIR)$(PREFIX) with desktop integration"

# Skipped under DESTDIR, where we are staging rather than touching a live system.
post-install:
ifeq ($(strip $(DESTDIR)),)
	-@update-desktop-database $(DESKTOP_PREFIX)/share/applications 2>/dev/null
	-@gtk-update-icon-cache -qtf $(DESKTOP_PREFIX)/share/icons/hicolor 2>/dev/null
endif

uninstall:
	@test -f $(BUILD_DIR)/install_manifest.txt || \
		{ echo "No $(BUILD_DIR)/install_manifest.txt -- nothing recorded to uninstall."; exit 1; }
	@# `|| [ -n "$$f" ]`: the manifest has no trailing newline, so a plain read
	@# loop drops the last entry.
	@while read -r f || [ -n "$$f" ]; do \
		[ -e "$(DESTDIR)$$f" ] || [ -L "$(DESTDIR)$$f" ] || continue; \
		echo "removing $(DESTDIR)$$f"; rm -f "$(DESTDIR)$$f"; \
	done < $(BUILD_DIR)/install_manifest.txt
	@$(MAKE) --no-print-directory post-install

clean:
	@test -d $(BUILD_DIR) && cmake --build $(BUILD_DIR) --target clean || true

distclean:
	rm -rf $(BUILD_DIR)

deps:
ifneq ($(shell command -v dnf 2>/dev/null),)
	sudo dnf install -y cmake ninja-build gcc-c++ pkgconf-pkg-config \
		qt6-qtbase-devel qt6-qttools-devel mesa-libGL-devel
else ifneq ($(shell command -v apt-get 2>/dev/null),)
	sudo apt-get update
	sudo apt-get install -y cmake ninja-build g++ pkg-config \
		qt6-base-dev qt6-base-dev-tools libgl1-mesa-dev
else
	@echo "Unsupported package manager. Install by hand: cmake, ninja, a C++17"
	@echo "compiler, Qt6 Widgets development files and libGL."
	@exit 1
endif
	@echo
	@echo "liblsl is not packaged by the distro:"
	@echo "  git clone --depth=1 --branch v1.17.7 https://github.com/sccn/liblsl"
	@echo "  cmake -S liblsl -B liblsl/build -DLSL_UNIXFOLDERS=ON -DCMAKE_INSTALL_PREFIX=/usr/local"
	@echo "  cmake --build liblsl/build --parallel && sudo cmake --install liblsl/build"
	@echo
	@echo "The Tobii Pro C SDK has to come from Tobii; extract it and set"
	@echo "TOBII_SDK_ROOT to the directory holding include/ and lib/."

help:
	@echo "Targets:"
	@echo "  deps            install build dependencies via dnf or apt"
	@echo "  build           configure and build (default)"
	@echo "  install         install to \$$PREFIX"
	@echo "  install-system  install plus the .desktop entry and icon"
	@echo "  uninstall       remove files listed in the install manifest"
	@echo "  clean           clean build artifacts"
	@echo "  distclean       remove the build directory entirely"
	@echo
	@echo "Variables (current values):"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  DESTDIR=$(DESTDIR)"
	@echo "  BUILD_DIR=$(BUILD_DIR)"
	@echo "  BUILD_TYPE=$(BUILD_TYPE)"
	@echo "  LSL_INSTALL_ROOT=$(LSL_INSTALL_ROOT)"
	@echo "  TOBII_SDK_ROOT=$(TOBII_SDK_ROOT)"
	@echo "  DESKTOP_PREFIX=$(DESKTOP_PREFIX)"
	@echo "  EXEC_PATH=$(EXEC_PATH)"
	@echo "  BUNDLE_SDK=$(BUNDLE_SDK)"
	@echo "  GENERATOR=$(GENERATOR)"
	@echo "  JOBS=$(JOBS)"
	@echo
	@echo "Example:"
	@echo "  sudo make install-system PREFIX=/opt/tobii-lsl TOBII_SDK_ROOT=/opt/tobii-sdk"

# SPDX-License-Identifier: MIT
#
# Copyright (C) 2018-2023 WireGuard LLC. All Rights Reserved.
#
# This Makefile builds the Go bridge once, as a precompiled binary
# `WireGuardKitGo.xcframework` that is committed into the repository. Consumers
# of the Swift package (and the Xcode project) link that xcframework directly
# and therefore do NOT need a Go toolchain to build. Run `make` here only when
# the Go sources or dependencies change, then commit the regenerated
# xcframework.

# Deployment targets — keep in sync with Package.swift and the Xcode project.
IPHONEOS_DEPLOYMENT_TARGET ?= 15.0
MACOSX_DEPLOYMENT_TARGET ?= 12.0

export PATH := $(PATH):/usr/local/bin:/opt/homebrew/bin
export CC ?= clang
LIPO ?= lipo
XCODEBUILD ?= xcodebuild

DESTDIR ?= $(CURDIR)
BUILDDIR ?= $(CURDIR)/.build
XCFRAMEWORK := $(DESTDIR)/WireGuardKitGo.xcframework

SDKROOT_macosx := $(shell xcrun --sdk macosx --show-sdk-path)
SDKROOT_iphoneos := $(shell xcrun --sdk iphoneos --show-sdk-path)
SDKROOT_iphonesimulator := $(shell xcrun --sdk iphonesimulator --show-sdk-path)

xcframework: $(XCFRAMEWORK)
version-header: $(DESTDIR)/wireguard-go-version.h

# Patched copy of GOROOT: makes timers account for time spent while the machine
# was asleep (mach_continuous_time instead of mach_absolute_time), which is
# common on mobile devices.
REAL_GOROOT := $(shell go env GOROOT 2>/dev/null)
export GOROOT := $(BUILDDIR)/goroot
$(GOROOT)/.prepared:
	[ -n "$(REAL_GOROOT)" ]
	mkdir -p "$(GOROOT)"
	rsync -a --delete --exclude=pkg/obj/go-build "$(REAL_GOROOT)/" "$(GOROOT)/"
	cat goruntime-*.diff | patch -p1 -f -N -r- -d "$(GOROOT)"
	touch "$@"

# build-arch: $(1)=output-stem $(2)=GOOS $(3)=GOARCH $(4)=SDKROOT $(5)=clang-target-triple
define build-arch
$(BUILDDIR)/$(1).a: export CGO_ENABLED := 1
$(BUILDDIR)/$(1).a: export GOOS := $(2)
$(BUILDDIR)/$(1).a: export GOARCH := $(3)
$(BUILDDIR)/$(1).a: export CGO_CFLAGS := -isysroot $(4) -target $(5)
$(BUILDDIR)/$(1).a: export CGO_LDFLAGS := -isysroot $(4) -target $(5)
$(BUILDDIR)/$(1).a: $(GOROOT)/.prepared go.mod
	@mkdir -p "$(BUILDDIR)"
	go build -ldflags=-w -trimpath -o "$$@" -buildmode c-archive
	@rm -f "$(BUILDDIR)/$(1).h"
endef

$(eval $(call build-arch,macos-arm64,darwin,arm64,$(SDKROOT_macosx),arm64-apple-macos$(MACOSX_DEPLOYMENT_TARGET)))
$(eval $(call build-arch,macos-amd64,darwin,amd64,$(SDKROOT_macosx),x86_64-apple-macos$(MACOSX_DEPLOYMENT_TARGET)))
$(eval $(call build-arch,ios-arm64,ios,arm64,$(SDKROOT_iphoneos),arm64-apple-ios$(IPHONEOS_DEPLOYMENT_TARGET)))
$(eval $(call build-arch,iossim-arm64,ios,arm64,$(SDKROOT_iphonesimulator),arm64-apple-ios$(IPHONEOS_DEPLOYMENT_TARGET)-simulator))
$(eval $(call build-arch,iossim-amd64,ios,amd64,$(SDKROOT_iphonesimulator),x86_64-apple-ios$(IPHONEOS_DEPLOYMENT_TARGET)-simulator))

# Per-platform fat static libraries.
$(BUILDDIR)/macos/libwg-go.a: $(BUILDDIR)/macos-arm64.a $(BUILDDIR)/macos-amd64.a
	@mkdir -p "$(dir $@)"
	$(LIPO) -create -output "$@" $^
$(BUILDDIR)/ios/libwg-go.a: $(BUILDDIR)/ios-arm64.a
	@mkdir -p "$(dir $@)"
	$(LIPO) -create -output "$@" $^
$(BUILDDIR)/iossimulator/libwg-go.a: $(BUILDDIR)/iossim-arm64.a $(BUILDDIR)/iossim-amd64.a
	@mkdir -p "$(dir $@)"
	$(LIPO) -create -output "$@" $^

# Headers (+ module map) bundled into every xcframework slice, so the library
# is importable as the `WireGuardKitGo` Clang module from Swift.
$(BUILDDIR)/include/module.modulemap: wireguard.h
	@mkdir -p "$(BUILDDIR)/include"
	cp wireguard.h "$(BUILDDIR)/include/wireguard.h"
	printf 'module WireGuardKitGo {\n    header "wireguard.h"\n    export *\n}\n' > "$@"

$(XCFRAMEWORK): $(BUILDDIR)/macos/libwg-go.a $(BUILDDIR)/ios/libwg-go.a $(BUILDDIR)/iossimulator/libwg-go.a $(BUILDDIR)/include/module.modulemap
	rm -rf "$(XCFRAMEWORK)"
	$(XCODEBUILD) -create-xcframework \
		-library "$(BUILDDIR)/macos/libwg-go.a" -headers "$(BUILDDIR)/include" \
		-library "$(BUILDDIR)/ios/libwg-go.a" -headers "$(BUILDDIR)/include" \
		-library "$(BUILDDIR)/iossimulator/libwg-go.a" -headers "$(BUILDDIR)/include" \
		-output "$(XCFRAMEWORK)"

# Extracts the wireguard-go commit from go.mod. Pure text processing — no Go
# toolchain required — so the Xcode app build can run it without Go installed.
$(DESTDIR)/wireguard-go-version.h: go.mod
	sed -E -n 's|.*golang\.zx2c4\.com/wireguard +v[0-9.]+-[0-9]+-([0-9a-f]{8})[0-9a-f]{4}.*|#define WIREGUARD_GO_VERSION "\1"|p' "$<" > "$@"

clean:
	rm -rf "$(BUILDDIR)" "$(XCFRAMEWORK)" "$(DESTDIR)/wireguard-go-version.h"

.PHONY: xcframework version-header clean

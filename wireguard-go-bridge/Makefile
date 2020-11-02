# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2018-2020 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.

# These are generally passed to us by xcode, but we set working defaults for standalone compilation too.
ARCHS ?= arm64 armv7
SDK_NAME ?= iphoneos
SDKROOT ?= $(shell xcrun --sdk $(SDK_NAME) --show-sdk-path)
CONFIGURATION_BUILD_DIR ?= $(CURDIR)/out
CONFIGURATION_TEMP_DIR ?= $(CURDIR)/.tmp

export CC ?= clang
LIPO ?= lipo
DESTDIR ?= $(CONFIGURATION_BUILD_DIR)
BUILDDIR ?= $(CONFIGURATION_TEMP_DIR)/wireguard-go-bridge

CFLAGS_PREFIX := $(if $(DEPLOYMENT_TARGET_CLANG_FLAG_NAME),-$(DEPLOYMENT_TARGET_CLANG_FLAG_NAME)=$($(DEPLOYMENT_TARGET_CLANG_ENV_NAME)),) -Wno-unused-command-line-argument -isysroot $(SDKROOT) -arch
GOARCH_arm64 := arm64
GOARCH_armv7 := arm
GOARCH_x86_64 := amd64

GO_VERSION := 1.13.4
GO_ARCH_MAP_x86_64 := amd64
GO_PLATFORM := $(shell uname -s | tr '[:upper:]' '[:lower:]')-$(GO_ARCH_MAP_$(shell uname -m))
GO_TARBALL := go$(GO_VERSION).$(GO_PLATFORM).tar.gz
GO_HASH_darwin-amd64 := a9088c44a984c4ba64179619606cc65d9d0cb92988012cfc94fbb29ca09edac7

build: $(DESTDIR)/libwg-go.a
go-patch: $(GOROOT)/.prepared
go-tarball: $(BUILDDIR)/$(GO_TARBALL)
version-header: $(DESTDIR)/wireguard-go-version.h

$(BUILDDIR)/$(GO_TARBALL):
	mkdir -p "$(@D)"
	curl -o "$@.tmp" "https://dl.google.com/go/$(GO_TARBALL)" && \
	echo "$(GO_HASH_$(GO_PLATFORM))  $@.tmp" | sha256sum -c && \
	mv "$@.tmp" "$@"

export GOROOT := $(BUILDDIR)/go-$(GO_VERSION)
GOTOOL:=$(GOROOT)/bin/go
$(GOROOT)/.prepared: $(BUILDDIR)/$(GO_TARBALL)
	mkdir -p "$(@D)"
	tar -C "$(GOROOT)" --strip-components=1 -xzf "$^" && \
	cat goruntime-*.diff | patch -p1 -f -N -r- -d "$(GOROOT)" && \
	touch "$@"

define libwg-go-a
$(BUILDDIR)/libwg-go-$(1).a: export CGO_ENABLED := 1
$(BUILDDIR)/libwg-go-$(1).a: export CGO_CFLAGS := $(CFLAGS_PREFIX) $(ARCH)
$(BUILDDIR)/libwg-go-$(1).a: export CGO_LDFLAGS := $(CFLAGS_PREFIX) $(ARCH)
$(BUILDDIR)/libwg-go-$(1).a: export GOOS := darwin
$(BUILDDIR)/libwg-go-$(1).a: export GOARCH := $(GOARCH_$(1))
$(BUILDDIR)/libwg-go-$(1).a: $(GOROOT)/.prepared go.mod
	$(GOTOOL) build -tags ios -ldflags=-w -trimpath -v -o "$(BUILDDIR)/libwg-go-$(1).a" -buildmode c-archive
	$(RM) "$(BUILDDIR)/libwg-go-$(1).h"
endef
$(foreach ARCH,$(ARCHS),$(eval $(call libwg-go-a,$(ARCH))))

$(DESTDIR)/wireguard-go-version.h: $(GOROOT)/.prepared go.mod
	$(GOTOOL) list -m golang.zx2c4.com/wireguard | sed -n 's/.*v\([0-9.]*\).*/#define WIREGUARD_GO_VERSION "\1"/p' > "$@"

$(DESTDIR)/libwg-go.a: $(foreach ARCH,$(ARCHS),$(BUILDDIR)/libwg-go-$(ARCH).a)
	@mkdir -vp "$(DESTDIR)"
	$(LIPO) -create -output "$@" $^

clean:
	$(RM) -r "$(BUILDDIR)" "$(DESTDIR)/libwg-go.a" "$(DESTDIR)/wireguard-go-version.h"

install: build

.PHONY: clean build version-header install prepared go-tarball go-patch

.DELETE_ON_ERROR:

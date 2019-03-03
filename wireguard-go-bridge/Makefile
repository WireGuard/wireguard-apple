# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2018-2019 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.

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

UPSTREAM_FILES := $(filter-out %/main.go %/queueconstants.go,$(wildcard ../wireguard-go/*/*.go) $(wildcard ../wireguard-go/*.go)) ../wireguard-go/go.mod ../wireguard-go/go.sum
DOWNSTREAM_FILES := $(wildcard src/*.go) $(wildcard src/*/*.go)
CFLAGS_PREFIX := $(if $(DEPLOYMENT_TARGET_CLANG_FLAG_NAME),-$(DEPLOYMENT_TARGET_CLANG_FLAG_NAME)=$($(DEPLOYMENT_TARGET_CLANG_ENV_NAME)),) -Wno-unused-command-line-argument -isysroot $(SDKROOT) -arch
GOARCH_arm64 := arm64
GOARCH_armv7 := arm
GOARCH_x86_64 := amd64
export GOOS := darwin
export CGO_ENABLED := 1

build: $(DESTDIR)/libwg-go.a
version-header: $(DESTDIR)/wireguard-go-version.h

GOBUILDARCH := $(GOARCH_$(shell uname -m))
GOBUILDOS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
GOBUILDVERSION := 1.12
GOBUILDTARBALL := go$(GOBUILDVERSION).$(GOBUILDOS)-$(GOBUILDARCH).tar.gz
GOBUILDTARBALLURL := https://dl.google.com/go/$(GOBUILDTARBALL)
GOBUILDVERSION_NEEDED := go version go$(GOBUILDVERSION) $(GOBUILDOS)/$(GOBUILDARCH)
export GOROOT := $(BUILDDIR)/goroot
export GOPATH := $(BUILDDIR)/gopath
export PATH := $(GOROOT)/bin:$(PATH)
GOBUILDVERSION_CURRENT := $(shell $(GOROOT)/bin/go version 2>/dev/null)
ifneq ($(GOBUILDVERSION_NEEDED),$(GOBUILDVERSION_CURRENT))
$(shell rm -f $(GOROOT)/bin/go)
endif
.cache/$(GOBUILDTARBALL):
	mkdir -p $(dir $@)
	curl -o $@ $(GOBUILDTARBALLURL) || { rm -f $@; exit 1; }

$(GOROOT)/bin/go: .cache/$(GOBUILDTARBALL)
	rm -rf "$(GOROOT)"
	mkdir -p "$(GOROOT)"
	tar -C "$(GOROOT)" --strip-components=1 -xzf - < .cache/$(GOBUILDTARBALL) || { rm -rf "$(GOROOT)"; exit 1; }
	patch -p1 -f -N -r- -d "$(GOROOT)" < goruntime-boottime-over-monotonic.diff || { rm -rf "$(GOROOT)"; exit 1; }
	touch $@

$(shell test "$$(cat "$(BUILDDIR)/.gobuildversion" 2>/dev/null)" = "$(GOBUILDVERSION_CURRENT)" || rm -f "$(DESTDIR)/libwg-go.a")

define libwg-go-a
$(BUILDDIR)/libwg-go-$(1).a: $(GOROOT)/bin/go
	CGO_CFLAGS="$(CFLAGS_PREFIX) $(ARCH)" \
	CGO_LDFLAGS="$(CFLAGS_PREFIX) $(ARCH)" \
	GOARCH="$(GOARCH_$(1))" \
	go build -tags ios -ldflags=-w -v -o "$(BUILDDIR)/libwg-go-$(1).a" -buildmode c-archive && go version > "$(BUILDDIR)/.gobuildversion"; \
	chmod -fR +w "$(GOPATH)/pkg/mod"; \
	ret=$$$$?; \
	rm -f "$(BUILDDIR)/libwg-go-$(1).h"; \
	exit $$$$ret
endef
$(foreach ARCH,$(ARCHS),$(eval $(call libwg-go-a,$(ARCH))))

$(DESTDIR)/wireguard-go-version.h: go.mod $(GOROOT)/bin/go
	go get -d -tags ios; chmod -fR +w "$(GOPATH)/pkg/mod"
	wggo="$(GOPATH)/pkg/mod/$$(sed -n 's/.*\(golang\.zx2c4\.com\/wireguard\) \(.*\)$$/\1@\2/p' go.mod)"; \
	sed -n 's/.*WireGuardGoVersion = "\(.*\)"/#define WIREGUARD_GO_VERSION "\1"/p' "$$wggo/device/version.go" > "$@"

$(DESTDIR)/libwg-go.a: $(foreach ARCH,$(ARCHS),$(BUILDDIR)/libwg-go-$(ARCH).a)
	@mkdir -vp "$(DESTDIR)"
	$(LIPO) -create -output "$@" $^

clean:
	rm -rf "$(BUILDDIR)" "$(DESTDIR)/libwg-go.a" "$(DESTDIR)/wireguard-go-version.h"

distclean: clean
	rm -rf .cache

install: build

.PHONY: distclean clean build version-header install

# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.

UPSTREAM_FILES := $(filter-out %/main.go %/queueconstants.go,$(wildcard ../wireguard-go/*/*.go) $(wildcard ../wireguard-go/*.go)) ../wireguard-go/go.mod ../wireguard-go/go.sum
DOWNSTREAM_FILES := $(wildcard src/*.go) $(wildcard src/*/*.go)

ARCHS ?= arm64 armv7 x86_64
GOARCH_arm64 := arm64
GOARCH_armv7 := arm
GOARCH_x86_64 := amd64
DEPLOYMENT_CFLAGS := $(DEPLOYMENT_TARGET_CLANG_FLAG_PREFIX)$($(DEPLOYMENT_TARGET_CLANG_ENV_NAME))
CGO_FLAGS_x86_64 := -arch x86_64 -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path) $(DEPLOYMENT_CFLAGS)
CGO_FLAGS_arm64 := -arch arm64 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) $(DEPLOYMENT_CFLAGS)
CGO_FLAGS_armv7 := -arch armv7 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) $(DEPLOYMENT_CFLAGS)
CC_x86_64 := $(shell xcrun --sdk iphonesimulator --find clang)
CC_arm64 := $(shell xcrun --sdk iphoneos --find clang)
CC_armv7 := $(shell xcrun --sdk iphoneos --find clang)
CONFIGURATION_BUILD_DIR ?= $(CURDIR)/out
CONFIGURATION_TEMP_DIR ?= $(CURDIR)/.tmp
DESTDIR ?= $(CONFIGURATION_BUILD_DIR)
BUILDDIR ?= $(CONFIGURATION_TEMP_DIR)/wireguard-go-bridge
export GOOS := darwin
export CGO_ENABLED := 1

build: $(DESTDIR)/libwg-go.a

define copy-src-to-build
$(subst $(1),$(BUILDDIR)/,$(2)): $(2)
	@mkdir -vp "$$(dir $$@)"
	@cp -vp "$$<" "$$@"
$(BUILDDIR)/.prepared: $(subst $(1),$(BUILDDIR)/,$(2))
endef

$(foreach FILE,$(UPSTREAM_FILES),$(eval $(call copy-src-to-build,../wireguard-go/,$(FILE))))
$(foreach FILE,$(DOWNSTREAM_FILES),$(eval $(call copy-src-to-build,src/,$(FILE))))

$(BUILDDIR)/.prepared:
	@touch "$@"

define libwg-go-a
$(BUILDDIR)/libwg-go-$(1).a: $(BUILDDIR)/.prepared
	cd "$(BUILDDIR)" || exit $$$$?; \
	export CC="$(CC_$(1))" \
	CGO_CFLAGS="$(CGO_FLAGS_$(1))" \
	CGO_LDFLAGS="$(CGO_FLAGS_$(1))" \
	GOARCH="$(GOARCH_$(1))" \
	GOPATH="$(BUILDDIR)/gopath"; \
	go get -tags ios || { ret=$$$$?; chmod -fR +w "$(BUILDDIR)/gopath/pkg/mod"; rm -rf "$(BUILDDIR)/gopath/pkg/mod"; exit $$$$ret; }; \
	chmod -fR +w "$(BUILDDIR)/gopath/pkg/mod"; \
	go build -tags ios -v -o "$(BUILDDIR)/libwg-go-$(1).a" -buildmode c-archive; \
	ret=$$$$?; \
	rm -f "$(BUILDDIR)/libwg-go-$(1).h"; \
	exit $$$$ret
endef
$(foreach ARCH,$(ARCHS),$(eval $(call libwg-go-a,$(ARCH))))

$(DESTDIR)/libwg-go.a: $(foreach ARCH,$(ARCHS),$(BUILDDIR)/libwg-go-$(ARCH).a)
	@mkdir -vp "$(DESTDIR)"
	xcrun --sdk iphoneos lipo -create -output "$@" $^

$(DESTDIR)/example: example.c $(DESTDIR)/libwg-go.a
	xcrun --sdk iphoneos clang -framework CoreFoundation -isysroot "$(shell xcrun --sdk iphoneos --show-sdk-path)" -arch arm64 -arch armv7 -L"$(DESTDIR)" -lwg-go -o "$@" "$<"

clean:
	rm -rf "$(BUILDDIR)" "$(DESTDIR)/libwg-go.a" "$(DESTDIR)/example"

.PHONY: clean build

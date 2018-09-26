# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.

FILES := $(filter-out %/main.go %/queueconstants.go,$(wildcard ../wireguard-go/*/*.go) $(wildcard ../wireguard-go/*.go))

ARCHES := arm64 armv7 x86_64
GOARCH_arm64 := arm64
GOARCH_armv7 := arm
GOARCH_x86_64 := amd64
CGO_FLAGS_x86_64 := -arch x86_64 -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path)
CGO_FLAGS_arm64 := -arch arm64 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path)
CGO_FLAGS_armv7 := -arch armv7 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path)
CC_x86_64 := $(shell xcrun --sdk iphonesimulator --find clang)
CC_arm64 := $(shell xcrun --sdk iphoneos --find clang)
CC_armv7 := $(shell xcrun --sdk iphoneos --find clang)
export GOOS := darwin
export CGO_ENABLED := 1

default: libwg-go.a

src/.prepared: $(FILES) src/git.zx2c4.com/wireguard-go/api-ios.go src/git.zx2c4.com/wireguard-go/tun/tun_ios.go
	find . -name '*.go' -type l -delete
	find . -type d -empty -delete
	mkdir -p $(subst ../wireguard-go/,./src/git.zx2c4.com/wireguard-go/,$(dir $(FILES)))
	$(foreach FILE,$(FILES),ln -sf $(abspath $(FILE)) $(subst ../wireguard-go/,./src/git.zx2c4.com/wireguard-go/,$(dir $(FILE)))$(notdir $(FILE));)
	GOPATH=$(CURDIR) go get -v -d git.zx2c4.com/wireguard-go
	touch $@

define libwg-go-a
libwg-go-$(1).a: $(FILES) src/git.zx2c4.com/wireguard-go/api-ios.go src/git.zx2c4.com/wireguard-go/tun/tun_ios.go src/.prepared
	CC="$(CC_$(1))" \
	CGO_CFLAGS="$(CGO_FLAGS_$(1))" \
	CGO_LDFLAGS="$(CGO_FLAGS_$(1))" \
	GOARCH=$(GOARCH_$(1)) \
	GOPATH=$(CURDIR) \
	go build -tags ios -v -o libwg-go-$(1).a -buildmode c-archive git.zx2c4.com/wireguard-go
	@rm -f libwg-go-$(1).h
endef
$(foreach ARCH,$(ARCHES),$(eval $(call libwg-go-a,$(ARCH))))

libwg-go.a: $(foreach ARCH,$(ARCHES),libwg-go-$(ARCH).a)
	xcrun --sdk iphoneos lipo -create -output $@ $^

example: example.c libwg-go.a
	xcrun --sdk iphoneos clang -framework CoreFoundation -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -arch arm64 -arch armv7 -L. -lwg-go -o example example.c

clean:
	rm -f libwg-go.a $(foreach ARCH,$(ARCHES),libwg-go-$(ARCH).a) example

.PHONY: clean default

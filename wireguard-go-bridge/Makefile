# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.

FILES := $(filter-out %/main.go,$(wildcard ../wireguard-go/*/*.go) $(wildcard ../wireguard-go/*.go))

# CLANG_FLAGS := --target=$(ANDROID_LLVM_TRIPLE) --gcc-toolchain=$(ANDROID_TOOLCHAIN_ROOT) --sysroot=$(ANDROID_SYSROOT)
# export CGO_CFLAGS := $(CLANG_FLAGS) $(CFLAGS)
# export CGO_LDFLAGS := $(CLANG_FLAGS) $(LDFLAGS)
# export CC := $(ANDROID_C_COMPILER)
# export GOARCH := $(NDK_GO_ARCH_MAP_$(ANDROID_ARCH_NAME))
export GOOS := darwin
export CGO_ENABLED := 1

default: example

libwg-go.so: $(FILES) src/git.zx2c4.com/wireguard-go/api-ios.go src/git.zx2c4.com/wireguard-go/tun/tun_ios.go
	find . -name '*.go' -type l -delete
	find . -type d -empty -delete
	mkdir -p $(subst ../wireguard-go/,./src/git.zx2c4.com/wireguard-go/,$(dir $(FILES)))
	$(foreach FILE,$(FILES),ln -sf $(abspath $(FILE)) $(subst ../wireguard-go/,./src/git.zx2c4.com/wireguard-go/,$(dir $(FILE)))$(notdir $(FILE));)
	GOPATH=$(PWD) go get -v -d git.zx2c4.com/wireguard-go
	GOPATH=$(PWD) go build -tags ios -v -o libwg-go.so -buildmode c-archive git.zx2c4.com/wireguard-go
	@rm -f libwg-go.h

example: example.c libwg-go.so
	$(CC) -L. -lwg-go -o example example.c

clean:
	rm -f libwg-go.so test

.PHONY: clean default

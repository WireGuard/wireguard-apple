#### Upgrading the WireGuard Dependency

WireGuard code is just a copy of files from the [official wg repo](https://git.zx2c4.com/wireguard-apple/about/) with some modifications to the makefile to build a whole xcframework and updating go dependencies.

Going forward, since the code in `WireGuardGoFoundationSource` is essentially just a shim around the wg go package, it is just a matter of updating go packages.

1. `cd` to `WireGuardGoFoundationSource`
1. Depending on intent, run one of the following update commands:

		# Update all dependencies to latest minor/patch versions
		go get -u ./...

		# Update only patch versions (safer)
		go get -u=patch ./...

1. Use discretion to run `go mod tidy` to cleanup afterwards
1. Confirm building `WireGuardGoFoundationSource` still works
	1. `make clean`
	1. `make build-xcframework`


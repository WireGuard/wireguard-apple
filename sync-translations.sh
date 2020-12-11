#!/bin/bash
set -ex
curl -Lo - https://crowdin.com/backend/download/project/wireguard.zip | bsdtar -C Sources/WireGuardApp -x -f - --strip-components 3 wireguard-apple
find Sources/WireGuardApp/*.lproj -type f -empty -delete
find Sources/WireGuardApp/*.lproj -type d -empty -delete
git add Sources/WireGuardApp/*.lproj

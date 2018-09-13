# [WireGuard](https://www.wireguard.com/) for iOS

To get started...

Make sure you have Go available. A homebrew install will do. `brew install go`

- Clone this repo.
  - `git clone https://git.zx2c4.com/wireguard-ios`
  - Init and update submodule: `git submodule init && git submodule update`
- Prepare WireGuard Go bindings
  - `cd wireguard-go-bridge && make`
- Prepare Xcode project
  - Run `pod install`
  - Open `WireGuard.xcworkspace`

## License

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License version 2 as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

    ---------------------------------------------------------------------------
    Additional Permissions For Submission to Apple App Store: Provided that you
    are otherwise in compliance with the GPLv2 for each covered work you convey
    (including without limitation making the Corresponding Source available in
    compliance with Section 3 of the GPLv2), you are granted the additional
    the additional permission to convey through the Apple App Store
    non-source executable versions of the Program as incorporated into each
    applicable covered work as Executable Versions only under the Mozilla
    Public License version 2.0 (https://www.mozilla.org/en-US/MPL/2.0/).
    


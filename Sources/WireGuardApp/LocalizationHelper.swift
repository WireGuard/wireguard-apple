// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

/// Gets the English string from Base.lproj as a fallback for missing translations.
func tr_base(_ key: String) -> String {
	let baseBundlePath: String? = Bundle.main.path(forResource: "Base", ofType: "lproj")
	let baseBundle: Bundle? = Bundle(path: baseBundlePath ?? "") ?? nil
	return baseBundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
}

func tr(_ key: String) -> String {
	return NSLocalizedString(key, value: tr_base(key), comment: "")
}

func tr(format: String, _ arguments: CVarArg...) -> String {
	return String(format: NSLocalizedString(format, value: tr_base(format), comment: ""), arguments: arguments)
}

// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

/// Gets the English string from the Base.lproj bundle, which can be used as a fallback when the translation for a certain language is missing.
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

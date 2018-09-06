//
//  String+Arrays.swift
//  WireGuard
//
//  Created by Eric Kuck on 8/15/18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

extension String {

    static func commaSeparatedStringFrom(elements: [String]) -> String {
        return elements.joined(separator: ",")
    }

    func commaSeparatedToArray() -> [String] {
        return components(separatedBy: .whitespaces)
            .joined()
            .split(separator: ",")
            .map(String.init)
    }

}

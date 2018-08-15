//
//  ValidatorsTests.swift
//  WireGuardTests
//
//  Created by Jeroen Leenarts on 15-08-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import XCTest
@testable import WireGuard

class ValidatorsTests: XCTestCase {
    func testEndpoint() throws {
        _ = try Endpoint(endpointString: "[2607:f938:3001:4000::aac]:12345")
        _ = try Endpoint(endpointString: "192.168.0.1:12345")
    }

    func testEndpoint_invalidIP() throws {
        func executeTest(endpointString: String, ipString: String, file: StaticString = #file, line: UInt = #line) {
            XCTAssertThrowsError(try Endpoint(endpointString: endpointString)) { (error) in
                guard case EndpointValidationError.invalidIP(let value) = error else {
                    return XCTFail("Unexpected error: \(error)", file: file, line: line)
                }
                XCTAssertEqual(value, ipString, file: file, line: line)
            }
        }

        executeTest(endpointString: "12345:12345", ipString: "12345")
        executeTest(endpointString: ":12345", ipString: "")
    }

    func testEndpoint_invalidPort() throws {
        func executeTest(endpointString: String, portString: String, file: StaticString = #file, line: UInt = #line) {
            XCTAssertThrowsError(try Endpoint(endpointString: endpointString)) { (error) in
                guard case EndpointValidationError.invalidPort(let value) = error else {
                    return XCTFail("Unexpected error: \(error)", file: file, line: line)
                }
                XCTAssertEqual(value, portString, file: file, line: line)
            }
        }

        executeTest(endpointString: ":", portString: "")
        executeTest(endpointString: "[2607:f938:3001:4000::aac]:-12345", portString: "-12345")
        executeTest(endpointString: "[2607:f938:3001:4000::aac]", portString: "aac]")
        executeTest(endpointString: "[2607:f938:3001:4000::aac]:", portString: "")
        executeTest(endpointString: "192.168.0.1:-12345", portString: "-12345")
        executeTest(endpointString: "192.168.0.1:", portString: "")

    }

    func testEndpoint_noIpAndPort() throws {

        func executeTest(endpointString: String, file: StaticString = #file, line: UInt = #line) {
            XCTAssertThrowsError(try Endpoint(endpointString: endpointString)) { (error) in
                guard case EndpointValidationError.noIpAndPort(let value) = error else {
                    return XCTFail("Unexpected error: \(error)", file: file, line: line)
                }
                XCTAssertEqual(value, endpointString, file: file, line: line)
            }
        }

        executeTest(endpointString: "192.168.0.1")
        executeTest(endpointString: "12345")
    }
}

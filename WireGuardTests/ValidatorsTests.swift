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
    func testIPv6Endpoint() throws {
        XCTFail("Still needs implementation")
    }

    func testIPv4Endpoint() throws {
        _ = try Endpoint(endpointString: "192.168.0.1:12345")
    }

    func testIPv4Endpoint_invalidIP() throws {
        XCTAssertThrowsError(try Endpoint(endpointString: "12345:12345")) { (error) in
            guard case EndpointValidationError.invalidIP(let value) = error else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(value, "12345")
        }
    }

    func testIPv4Endpoint_invalidPort() throws {
        XCTAssertThrowsError(try Endpoint(endpointString: "192.168.0.1:-12345")) { (error) in
            guard case EndpointValidationError.invalidPort(let value) = error else {
                return XCTFail("Unexpected error")
            }
            XCTAssertEqual(value, "-12345")
        }
    }

    func testIPv4Endpoint_noIpAndPort() throws {

        func executeTest(endpointString: String) {
            XCTAssertThrowsError(try Endpoint(endpointString: endpointString)) { (error) in
                guard case EndpointValidationError.noIpAndPort(let value) = error else {
                    return XCTFail("Unexpected error")
                }
                XCTAssertEqual(value, endpointString, file: #file, line: #line)
            }
        }

        executeTest(endpointString: ":")
        executeTest(endpointString: "192.168.0.1")
        executeTest(endpointString: "192.168.0.1:")
        executeTest(endpointString: ":12345")
        executeTest(endpointString: "12345")
    }
}

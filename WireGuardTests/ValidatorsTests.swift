//
//  ValidatorsTests.swift
//  WireGuardTests
//
//  Created by Jeroen Leenarts on 15-08-18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
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

    func testCIDRAddress() throws {
        _ = try CIDRAddress(stringRepresentation: "2607:f938:3001:4000::aac/24")
        _ = try CIDRAddress(stringRepresentation: "192.168.0.1/24")
    }

    func testIPv4CIDRAddress() throws {
        _ = try CIDRAddress(stringRepresentation: "192.168.0.1/24")
    }

    func testCIDRAddress_invalidIP() throws {
        func executeTest(stringRepresentation: String, ipString: String, file: StaticString = #file, line: UInt = #line) {
            XCTAssertThrowsError(try CIDRAddress(stringRepresentation: stringRepresentation)) { (error) in
                guard case CIDRAddressValidationError.invalidIP(let value) = error else {
                    return XCTFail("Unexpected error: \(error)", file: file, line: line)
                }
                XCTAssertEqual(value, ipString, file: file, line: line)
            }
        }

        executeTest(stringRepresentation: "12345/12345", ipString: "12345")
        executeTest(stringRepresentation: "/12345", ipString: "")
    }

    func testCIDRAddress_invalidSubnet() throws {
        func executeTest(stringRepresentation: String, subnetString: String, file: StaticString = #file, line: UInt = #line) {
            XCTAssertThrowsError(try CIDRAddress(stringRepresentation: stringRepresentation)) { (error) in
                guard case CIDRAddressValidationError.invalidSubnet(let value) = error else {
                    return XCTFail("Unexpected error: \(error)", file: file, line: line)
                }
                XCTAssertEqual(value, subnetString, file: file, line: line)
            }
        }

        executeTest(stringRepresentation: "/", subnetString: "")
        executeTest(stringRepresentation: "2607:f938:3001:4000::aac/a", subnetString: "a")
        executeTest(stringRepresentation: "2607:f938:3001:4000:/aac", subnetString: "aac")
        executeTest(stringRepresentation: "2607:f938:3001:4000::aac/", subnetString: "")
        executeTest(stringRepresentation: "192.168.0.1/a", subnetString: "a")
        executeTest(stringRepresentation: "192.168.0.1/", subnetString: "")

    }

    func testCIDRAddress_noIpAndSubnet() throws {

        func executeTest(stringRepresentation: String, file: StaticString = #file, line: UInt = #line) {
            XCTAssertThrowsError(try CIDRAddress(stringRepresentation: stringRepresentation)) { (error) in
                guard case CIDRAddressValidationError.noIpAndSubnet(let value) = error else {
                    return XCTFail("Unexpected error: \(error)", file: file, line: line)
                }
                XCTAssertEqual(value, stringRepresentation, file: file, line: line)
            }
        }

        executeTest(stringRepresentation: "192.168.0.1")
        executeTest(stringRepresentation: "12345")
    }

    // swiftlint:disable next function_body_length
    func testIPv4CIDRAddressSubnetConversion() throws {
        // swiftlint:disable force_try
        let cidrAddress1 = try! CIDRAddress(stringRepresentation: "128.0.0.0/1")!
        XCTAssertEqual(cidrAddress1.ipAddress, cidrAddress1.subnetString)
        let cidrAddress2 = try! CIDRAddress(stringRepresentation: "192.0.0.0/2")!
        XCTAssertEqual(cidrAddress2.ipAddress, cidrAddress2.subnetString)
        let cidrAddress3 = try! CIDRAddress(stringRepresentation: "224.0.0.0/3")!
        XCTAssertEqual(cidrAddress3.ipAddress, cidrAddress3.subnetString)
        let cidrAddress4 = try! CIDRAddress(stringRepresentation: "240.0.0.0/4")!
        XCTAssertEqual(cidrAddress4.ipAddress, cidrAddress4.subnetString)
        let cidrAddress5 = try! CIDRAddress(stringRepresentation: "248.0.0.0/5")!
        XCTAssertEqual(cidrAddress5.ipAddress, cidrAddress5.subnetString)
        let cidrAddress6 = try! CIDRAddress(stringRepresentation: "252.0.0.0/6")!
        XCTAssertEqual(cidrAddress6.ipAddress, cidrAddress6.subnetString)
        let cidrAddress7 = try! CIDRAddress(stringRepresentation: "254.0.0.0/7")!
        XCTAssertEqual(cidrAddress7.ipAddress, cidrAddress7.subnetString)
        let cidrAddress8 = try! CIDRAddress(stringRepresentation: "255.0.0.0/8")!
        XCTAssertEqual(cidrAddress8.ipAddress, cidrAddress8.subnetString)
        let cidrAddress9 = try! CIDRAddress(stringRepresentation: "255.128.0.0/9")!
        XCTAssertEqual(cidrAddress9.ipAddress, cidrAddress9.subnetString)
        let cidrAddress10 = try! CIDRAddress(stringRepresentation: "255.192.0.0/10")!
        XCTAssertEqual(cidrAddress10.ipAddress, cidrAddress10.subnetString)
        let cidrAddress11 = try! CIDRAddress(stringRepresentation: "255.224.0.0/11")!
        XCTAssertEqual(cidrAddress11.ipAddress, cidrAddress11.subnetString)
        let cidrAddress12 = try! CIDRAddress(stringRepresentation: "255.240.0.0/12")!
        XCTAssertEqual(cidrAddress12.ipAddress, cidrAddress12.subnetString)
        let cidrAddress13 = try! CIDRAddress(stringRepresentation: "255.248.0.0/13")!
        XCTAssertEqual(cidrAddress13.ipAddress, cidrAddress13.subnetString)
        let cidrAddress14 = try! CIDRAddress(stringRepresentation: "255.252.0.0/14")!
        XCTAssertEqual(cidrAddress14.ipAddress, cidrAddress14.subnetString)
        let cidrAddress15 = try! CIDRAddress(stringRepresentation: "255.254.0.0/15")!
        XCTAssertEqual(cidrAddress15.ipAddress, cidrAddress15.subnetString)
        let cidrAddress16 = try! CIDRAddress(stringRepresentation: "255.255.0.0/16")!
        XCTAssertEqual(cidrAddress16.ipAddress, cidrAddress16.subnetString)
        let cidrAddress17 = try! CIDRAddress(stringRepresentation: "255.255.128.0/17")!
        XCTAssertEqual(cidrAddress17.ipAddress, cidrAddress17.subnetString)
        let cidrAddress18 = try! CIDRAddress(stringRepresentation: "255.255.192.0/18")!
        XCTAssertEqual(cidrAddress18.ipAddress, cidrAddress18.subnetString)
        let cidrAddress19 = try! CIDRAddress(stringRepresentation: "255.255.224.0/19")!
        XCTAssertEqual(cidrAddress19.ipAddress, cidrAddress19.subnetString)
        let cidrAddress20 = try! CIDRAddress(stringRepresentation: "255.255.240.0/20")!
        XCTAssertEqual(cidrAddress20.ipAddress, cidrAddress20.subnetString)
        let cidrAddress21 = try! CIDRAddress(stringRepresentation: "255.255.248.0/21")!
        XCTAssertEqual(cidrAddress21.ipAddress, cidrAddress21.subnetString)
        let cidrAddress22 = try! CIDRAddress(stringRepresentation: "255.255.252.0/22")!
        XCTAssertEqual(cidrAddress22.ipAddress, cidrAddress22.subnetString)
        let cidrAddress23 = try! CIDRAddress(stringRepresentation: "255.255.254.0/23")!
        XCTAssertEqual(cidrAddress23.ipAddress, cidrAddress23.subnetString)
        let cidrAddress24 = try! CIDRAddress(stringRepresentation: "255.255.255.0/24")!
        XCTAssertEqual(cidrAddress24.ipAddress, cidrAddress24.subnetString)
        let cidrAddress25 = try! CIDRAddress(stringRepresentation: "255.255.255.128/25")!
        XCTAssertEqual(cidrAddress25.ipAddress, cidrAddress25.subnetString)
        let cidrAddress26 = try! CIDRAddress(stringRepresentation: "255.255.255.192/26")!
        XCTAssertEqual(cidrAddress26.ipAddress, cidrAddress26.subnetString)
        let cidrAddress27 = try! CIDRAddress(stringRepresentation: "255.255.255.224/27")!
        XCTAssertEqual(cidrAddress27.ipAddress, cidrAddress27.subnetString)
        let cidrAddress28 = try! CIDRAddress(stringRepresentation: "255.255.255.240/28")!
        XCTAssertEqual(cidrAddress28.ipAddress, cidrAddress28.subnetString)
        let cidrAddress29 = try! CIDRAddress(stringRepresentation: "255.255.255.248/29")!
        XCTAssertEqual(cidrAddress29.ipAddress, cidrAddress29.subnetString)
        let cidrAddress30 = try! CIDRAddress(stringRepresentation: "255.255.255.252/30")!
        XCTAssertEqual(cidrAddress30.ipAddress, cidrAddress30.subnetString)
        let cidrAddress31 = try! CIDRAddress(stringRepresentation: "255.255.255.254/31")!
        XCTAssertEqual(cidrAddress31.ipAddress, cidrAddress31.subnetString)
        let cidrAddress32 = try! CIDRAddress(stringRepresentation: "255.255.255.255/32")!
        XCTAssertEqual(cidrAddress32.ipAddress, cidrAddress32.subnetString)
        // swiftlint:enable force_try
    }

}

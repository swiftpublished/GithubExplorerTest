// ParameterizedTestGuide.swift

import Testing
import XCTest

/// # Parameterized Testing Guide
///
/// This file demonstrates how parameterized testing in Swift Testing compares
/// to the traditional approach in XCTest, showing how it reduces code duplication
/// and improves test organization.

// MARK: - System Under Test

/// The code we're testing - a simple email validator
struct EmailValidator {
    static func isValid(_ email: String) -> Bool {
        // Simple email validation logic:
        // - Contains @
        // - Has something before and after @
        // - Has a domain extension after a period
        let components = email.split(separator: "@")
        guard components.count == 2 else { return false }

        let username = components[0]
        let domain = components[1]

        guard !username.isEmpty, domain.contains(".") else { return false }

        let domainComponents = domain.split(separator: ".")
        guard domainComponents.count >= 2, !domainComponents.last!.isEmpty else { return false }

        return true
    }
}

// MARK: - XCTest Approach

/// The traditional XCTest approach requires separate test methods
/// or manually looping through test cases
class EmailValidatorXCTests: XCTestCase {
    func testValidEmailWithSimpleDomain() {
        XCTAssertTrue(EmailValidator.isValid("user@example.com"))
    }

    func testValidEmailWithSubdomain() {
        XCTAssertTrue(EmailValidator.isValid("user@sub.example.com"))
    }

    func testInvalidEmailMissingAt() {
        XCTAssertFalse(EmailValidator.isValid("userexample.com"))
    }

    func testInvalidEmailMissingUsername() {
        XCTAssertFalse(EmailValidator.isValid("@example.com"))
    }

    func testInvalidEmailMissingDomain() {
        XCTAssertFalse(EmailValidator.isValid("user@"))
    }

    func testInvalidEmailMissingDotInDomain() {
        XCTAssertFalse(EmailValidator.isValid("user@examplecom"))
    }

    // Alternative approach - using a loop
    func testMultipleEmails() {
        let testCases: [(email: String, isValid: Bool)] = [
            ("user@example.com", true),
            ("user@sub.example.com", true),
            ("userexample.com", false),
            ("@example.com", false),
            ("user@", false),
            ("user@examplecom", false)
        ]

        for testCase in testCases {
            XCTAssertEqual(
                EmailValidator.isValid(testCase.email),
                testCase.isValid,
                "Email validation failed for: \(testCase.email)"
            )
        }
    }
}

// MARK: - Swift Testing Approach

/// Using Swift Testing's parameterized tests
struct EmailValidatorTests {

    // Define test data once
    static let testCases: [(email: String, isValid: Bool)] = [
        ("user@example.com", true),
        ("user@sub.example.com", true),
        ("user.name@example.com", true),
        ("user+tag@example.com", true),
        ("user-name@example.co.uk", true),
        ("userexample.com", false),
        ("@example.com", false),
        ("user@", false),
        ("user@examplecom", false),
        ("", false),
        ("user@.com", false)
    ]

    // Single parameterized test that handles all cases
    @Test(arguments: testCases)
    func validatesEmail(emailTestCase: (email: String, isValid: Bool)) {
        // Parameterized tests receive the individual test case as a parameter
        let (email, expectedResult) = emailTestCase

        // Test logic remains the same, but runs for each test case
        #expect(EmailValidator.isValid(email) == expectedResult,
               "Email validation incorrect for: \(email)")
    }

    // You can also unpack the tuple in the parameter directly
    @Test(arguments: testCases)
    func validatesEmailUnpacked(email: String, expectedResult: Bool) {
        #expect(EmailValidator.isValid(email) == expectedResult,
               "Email validation incorrect for: \(email)")
    }

    // Multiple argument lists are also supported
    static let emails = ["user@example.com", "invalid", "user@sub.domain.com"]
    static let expectedResults = [true, false, true]

    @Test(arguments: zip(emails, expectedResults))
    func validatesEmailWithSeparateArrays(email: String, expectedResult: Bool) {
        #expect(EmailValidator.isValid(email) == expectedResult)
    }

    // Pass test cases directly to the @Test macro
    @Test(arguments: [
        ("user@example.com", true),
        ("user@sub.example.com", true),
        ("user.name@example.com", true),
        ("user+tag@example.com", true),
        ("userexample.com", false),
        ("@example.com", false)
    ])
    func validatesEmailInlineCases(email: String, isValid: Bool) {
        #expect(EmailValidator.isValid(email) == isValid,
               "Email validation incorrect for: \(email)")
    }
}

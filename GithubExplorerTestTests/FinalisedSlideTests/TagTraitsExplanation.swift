import Testing
import XCTest
@testable import GithubExplorerTest

// ===========================================================================================
// TAG TRAITS IN SWIFT TESTING: COMPREHENSIVE GUIDE
// ===========================================================================================
//
// Tags are one of the most powerful organizational features in Swift Testing.
// They let you categorize tests semantically and filter them during test runs.

// ===========================================================================================
// 1. DEFINING TAGS
// ===========================================================================================

// Tags are defined using the @Tag attribute in an extension of the Tag type
extension Tag {
    // Define custom tags for different test categories
    @Tag static var ui: Self
    @Tag static var network: Self
    @Tag static var performance: Self
    @Tag static var security: Self
    @Tag static var accessibility: Self
    @Tag static var smoke: Self
    @Tag static var regression: Self
    @Tag static var integration: Self
    @Tag static var flaky: Self

    // Feature-specific tags
    @Tag static var auth: Self
    @Tag static var payment: Self

    @Tag static var documentation: Self
}

// ===========================================================================================
// 2. APPLYING TAGS TO INDIVIDUAL TESTS
// ===========================================================================================

struct TaggingIndividualTests {
    // Basic example - single tag
    @Test(.tags(.ui))
    func testUIComponents() {
        // A UI test that validates interface components
        #expect(true)
    }

    // Multiple tags on a single test
    @Test(.tags(.network, .performance))
    func testNetworkPerformance() {
        // This test is both a network test AND a performance test
        #expect(true)
    }

    // Combining tags with other traits
    @Test(.tags(.flaky), .timeLimit(.minutes(1)))
    func testFlakyWithTimeLimit() {
        // Tests can have multiple traits - both tags and time limits
        #expect(true)
    }
}

// ===========================================================================================
// 3. APPLYING TAGS TO TEST SUITES
// ===========================================================================================

// Tags applied to a suite are inherited by all tests in that suite
@Suite(.tags(.integration))
struct IntegrationTestSuite {
    // These tests inherit the .integration tag from the suite

    @Test
    func testIntegrationFeatureA() {
        #expect(true)
    }

    @Test
    func testIntegrationFeatureB() {
        #expect(true)
    }

    // You can add additional tags to specific tests
    @Test(.tags(.security))
    func testSecureIntegration() {
        // This test has BOTH .integration (from suite) and .security tags
        #expect(true)
    }
}

// ===========================================================================================
// 4. PRACTICAL USE CASES FOR TAGS
// ===========================================================================================

struct RealWorldTagExamples {
    // SMOKE TESTS: Run quickly to verify basic functionality
    @Test(.tags(.smoke))
    func basicAppLaunchTest() {
        // A fast test that verifies the app launches correctly
        #expect(true)
    }

    // PERFORMANCE TESTS: Measure execution time or resource usage
    @Test(.tags(.performance))
    func databaseQueryPerformanceTest() {
        // Test that measures database query performance
        #expect(true)
    }

    // FLAKY TESTS: Tests that occasionally fail due to timing or external factors
    @Test(.tags(.flaky, .network))
    func occasionallyFailingNetworkTest() {
        // Test that sometimes fails due to network conditions
        #expect(true)
    }

    // REGRESSION TESTS: Verify specific bug fixes
    @Test(.tags(.regression), .bug("JIRA-1234"))
    func verifyBugFix() {
        // Test that confirms a specific bug is fixed
        #expect(true)
    }
}

// ===========================================================================================
// 5. HOW TO RUN TAGGED TESTS
// ===========================================================================================
/*
   In Xcode:
   ---------
   1. Click on the Test Navigator (diamond icon)
   2. Right-click on your test target
   3. Select "New Test Plan"
   4. In the test plan, click "Tests" tab
   5. Use the "Filter" field and enter: tag:performance (to run performance tests)
   6. You can create multiple test plans for different scenarios

   From Command Line:
   -----------------
   1. Run specific tags with the --filter option:
      swift test --filter "tag=smoke"

   2. Run tests with multiple tags (AND condition):
      swift test --filter "tag=network&tag=performance"

   3. Run tests with any of multiple tags (OR condition):
      swift test --filter "tag=smoke|tag=regression"

   4. Exclude tests with certain tags:
      swift test --filter "!tag=flaky"

   5. Combine with other filters:
      swift test --filter "tag=ui&name=login"
*/

// ===========================================================================================
// 6. COMPARISON WITH XCTEST: WHAT YOU'RE MISSING
// ===========================================================================================

// In XCTest, there's no built-in tagging system.
// Developers typically resort to these workarounds:

class XCTestTagWorkArounds: XCTestCase {
    // Workaround 1: Use naming conventions (error-prone and not filterable)
    func test_UI_LoginScreen() {
        // Prefix with "UI" to indicate a UI test
        XCTAssertTrue(true)
    }

    // Workaround 2: Use separate test classes per category (inflexible)
    // Example: Create UITests, NetworkTests, PerformanceTests classes

    // Workaround 3: Use test plans with name-based filtering (brittle)
    func testPerformance_DatabaseQuery() {
        // Rely on string-based filtering in test plans
        XCTAssertTrue(true)
    }

    // Workaround 4: Skip tests conditionally (complex and error-prone)
    func testNetworkFeature() throws {
        // Skip test based on environment variables
        let runNetworkTests = ProcessInfo.processInfo.environment["RUN_NETWORK_TESTS"] == "YES"
        try XCTSkipIf(!runNetworkTests, "Skipping network tests")

        XCTAssertTrue(true)
    }

    // LIMITATIONS OF XCTEST APPROACHES:
    // 1. No semantic meaning - just string conventions
    // 2. Can't easily combine categories (e.g., both "performance" AND "network")
    // 3. No inheritance of categories (unlike suite tags in Swift Testing)
    // 4. More code and complexity to manage test filtering
    // 5. No compile-time checking of categories (typos can be easily introduced)
    // 6. Test plans become complex and hard to maintain
}

// ===========================================================================================
// 7. ORGANIZATIONAL BEST PRACTICES
// ===========================================================================================

struct TagBestPractices {
    // Group tests both by FEATURE and by TEST TYPE using tags

    // Feature: Authentication, Type: UI
    @Test(.tags(.ui, .auth))
    func testLoginScreen() {
        #expect(true)
    }

    // Feature: Authentication, Type: Security
    @Test(.tags(.security, .auth))
    func testPasswordStrength() {
        #expect(true)
    }

    // Feature: Payment, Type: Integration
    @Test(.tags(.integration, .payment))
    func testPaymentProcessing() {
        #expect(true)
    }

    // PRACTICAL CI/CD WORKFLOW EXAMPLES:
    // 1. PR builds: Run only smoke tests
    //    swift test --filter "tag=smoke"
    //
    // 2. Nightly builds: Run everything except flaky tests
    //    swift test --filter "!tag=flaky"
    //
    // 3. Release builds: Run regression + integration tests
    //    swift test --filter "tag=regression|tag=integration"
    //
    // 4. Pre-submission: Run tests for specific feature being changed
    //    swift test --filter "tag=auth"
}

// ===========================================================================================
// CONCLUSION
// ===========================================================================================
//
// Swift Testing's tag system provides significant advantages:
//
// 1. SEMANTIC ORGANIZATION: Categorize tests by purpose, feature, or behavior
// 2. COMPILE-TIME VERIFICATION: Tags are verified by the compiler
// 3. FLEXIBLE FILTERING: Run specific subsets of tests easily
// 4. HIERARCHICAL INHERITANCE: Suite tags apply to all contained tests
// 5. COMBINATORIAL SELECTION: Select tests matching multiple criteria
//
// This makes test organization and execution much more manageable,
// especially in large codebases with thousands of tests.

// ===========================================================================================
// 8. ORGANIZING TAGS WITH NAMESPACES (RECOMMENDED FOR LARGER PROJECTS)
// ===========================================================================================

// For larger projects, you can organize tags using namespaces via nested enums
// This provides better organization and prevents tag name collisions

// Define namespace enums within Tag
extension Tag {
    // Test types namespace
    enum TestType {}

    // Features namespace
    enum Features {}

    // Modules namespace
    enum Modules {}
}

// Define tags within the TestType namespace
extension Tag.TestType {
    @Tag static var unit: Tag
    @Tag static var integration: Tag
    @Tag static var e2e: Tag
    @Tag static var performance: Tag
}

// Define tags within the Features namespace
extension Tag.Features {
    @Tag static var auth: Tag
    @Tag static var payment: Tag
    @Tag static var profile: Tag
    @Tag static var notifications: Tag
}

// Define tags within the Modules namespace
extension Tag.Modules {
    @Tag static var core: Tag
    @Tag static var ui: Tag
    @Tag static var networking: Tag
    @Tag static var database: Tag
}

// Demo of using namespaced tags
struct NamespacedTagsDemo {
    // Using namespaced tags individually
    @Test(.tags(.TestType.unit))
    func simpleUnitTest() {
        #expect(true)
    }

    // Combining tags from different namespaces
    @Test(.tags(.Features.auth, .TestType.integration))
    func testAuthIntegration() {
        #expect(true)
    }

    // Complex combination across multiple namespaces
    @Test(.tags(.Modules.networking, .Features.payment, .TestType.e2e))
    func endToEndPaymentNetworkTest() {
        #expect(true)
    }

    // Apply namespaced tags to test suites too
    @Suite(.tags(.Modules.database))
    struct DatabaseTests {
        @Test(.tags(.Features.auth))
        func testUserCredentialStorage() {
            #expect(true)
        }

        // This test has both .Modules.database (from the suite) and .TestType.performance tags
        @Test(.tags(.TestType.performance))
        func testDatabaseQueryPerformance() {
            #expect(true)
        }
    }
}

// Benefits of namespaced tags:
// 1. Better organization in large projects
// 2. Clearer categorization (TestType.unit vs Features.auth)
// 3. Reduced risk of tag name collisions
// 4. Easier to understand tag relationships
// 5. More maintainable as the test suite grows

// Filtering works the same way with namespaced tags:
// swift test --filter "tag=TestType.unit"
// swift test --filter "tag=Features.auth&tag=TestType.integration"

import Testing
import XCTest
@testable import GithubExplorerTest

// ===========================================================================================
// BUG TRAITS IN SWIFT TESTING: COMPREHENSIVE GUIDE
// ===========================================================================================
//
// Bug traits allow you to associate tests with specific bugs, track fixes,
// and handle known issues in your tests. This creates a bridge between your
// test suite and your issue tracking system.

// ===========================================================================================
// 1. ASSOCIATING TESTS WITH BUGS
// ===========================================================================================

struct BugAssociationExamples {
    // Basic example - associate test with a bug by ID
    @Test(.bug(id: 12345))
    func testFeatureWithKnownBug() {
        // This test is linked to bug #12345
        #expect(true)
    }

    // Associate a test with a bug by URL
    @Test(.bug("https://github.com/myorg/myrepo/issues/789"))
    func testGitHubIssue() {
        // This test is linked to a GitHub issue
        #expect(true)
    }

    // Associate with Apple Feedback bugs
    @Test(.bug(id: "FB12345678"))
    func testAppleFeedbackBug() {
        // The "FB" prefix is automatically recognized as an Apple Feedback bug
        #expect(true)
    }

    // Add a comment about the bug
    @Test(.bug("Fixes color rendering in dark mode", id: 4567))
    func testDarkModeRendering() {
        // Bug with description and ID
        #expect(true)
    }

    // Associate multiple bugs with a single test
    @Test(.bug(id: 123), .bug(id: 456))
    func testFixesMultipleIssues() {
        // This test is associated with two different bugs
        #expect(true)
    }
}

// ===========================================================================================
// 2. TRACKING BUG FIXES
// ===========================================================================================

struct BugFixVerificationExamples {
    // Using bug traits to document fixed issues
    @Test(.bug("Fixed in v2.1.3", id: "JIRA-1234"))
    func testPreviouslyBrokenFeature() {
        // This test verifies a bug fix
        let result = 2 + 2
        #expect(result == 4)
    }

    // Regression tests suite with bug associations
    @Suite("Regression Tests")
    struct RegressionTests {
        @Test(.bug("UI rendering issue fixed", id: "UI-567"))
        func testUIRenderingRegression() {
            // Test that verifies a UI bug was fixed
            #expect(true)
        }

        @Test(.bug("Data corruption issue", id: "CRITICAL-789"))
        func testDataIntegrityRegression() {
            // Test that verifies data is no longer corrupted
            #expect(true)
        }
    }
}

// ===========================================================================================
// 3. WORKING WITH KNOWN ISSUES
// ===========================================================================================

struct KnownIssueExamples {
    // Handling a test with a known issue that will always fail
    @Test
    func testFeatureWithKnownFailure() {
        // Use withKnownIssue to document a section of code that has a known issue
        withKnownIssue("Button animation is broken in iOS 17") {
            // This code is expected to fail, but won't fail the test
            let animationWorked = false
            #expect(animationWorked)
        }

        // Rest of the test continues normally
        #expect(true)
    }

    // Handling intermittent failures
    @Test
    func testIntermittentNetworkIssue() {
        withKnownIssue("Network connectivity sometimes fails", isIntermittent: true) {
            // Code that might occasionally fail
            let networkAvailable = Bool.random() // Simulating intermittent failures
            #expect(networkAvailable)
        }
    }

    // Conditionally enabling known issue handling
    @Test
    func testConditionalKnownIssue() {
        let isIOSDevice = true // Replace with actual platform check

        withKnownIssue("Bug only occurs on iOS") {
            // Test code that's expected to fail on iOS
            #expect(false)
        } when: {
            // Only consider this a known issue on iOS devices
            isIOSDevice
        }
    }

    // Matching specific issue types
    @Test
    func testMatchingSpecificErrors() {
        do {
            try withKnownIssue("Only certain errors are expected") {
                // Code that throws an error
                throw NSError(domain: "com.example", code: 123)
            } matching: { issue in
                // Only match specific error types
                if let error = issue.error as NSError? {
                    return error.domain == "com.example" && error.code == 123
                }
                return false
            }
        } catch {
            // Handle the error if it's not caught by withKnownIssue
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// ===========================================================================================
// 4. PRACTICAL USE CASES FOR BUG TRAITS
// ===========================================================================================

struct BugTraitUseCases {
    // REGRESSION TESTING: Track fixed bugs to prevent regressions
    @Test(.bug(id: "UI-123", "Text overflow issue fixed"))
    func testTextOverflowFixed() {
        // Test verifies that a previously broken feature now works
        #expect(true)
    }

    // WORK IN PROGRESS: Document features being actively worked on
    @Test
    func testFeatureInDevelopment() {
        // Associate a known issue with a bug comment
        withKnownIssue("Feature still under development (JIRA-456)") {
            // Test for functionality that's still being implemented
            #expect(false)
        }
    }

    // RELEASE NOTES: Automatically generate fixed issue lists
    @Test(.bug(id: "AUTH-789", "Login timeout issue"))
    func testLoginNoLongerTimesOut() {
        // Fixed issue that would be highlighted in release notes
        #expect(true)
    }

    // FLAKY TESTS: Handle tests that occasionally fail due to external factors
    @Test
    func testOccasionallyFailingFeature() {
        // Use isIntermittent for tests that sometimes fail
        withKnownIssue("External API occasionally times out (github.com/externalapi/issues/123)",
                       isIntermittent: true) {
            // Test that sometimes fails due to external dependency
            #expect(Bool.random())
        }
    }
}

// ===========================================================================================
// 5. HOW TO RUN TESTS WITH BUG ASSOCIATIONS
// ===========================================================================================
/*
   In Xcode:
   ---------
   1. Bug associations appear in the test navigator and test results
   2. When a test with a known issue fails as expected, it's marked differently
      in the UI (usually with a yellow triangle instead of a red X)
   3. You can use test plans to filter or group tests by their bug associations

   From Command Line:
   -----------------
   1. Run tests associated with a specific bug:
      swift test --filter "bug=12345"

   2. Run tests that verify fixes for a specific bug:
      swift test --filter "bug=JIRA-123"

   3. Exclude tests with known issues:
      swift test --filter "!hasKnownIssue"
*/

// ===========================================================================================
// 6. COMPARISON WITH XCTEST: WHAT YOU'RE MISSING
// ===========================================================================================

// In XCTest, there's limited support for bug tracking:

class XCTestBugWorkArounds: XCTestCase {
    // Workaround 1: Document bugs in test names or comments (no programmatic tracking)
    func test_BUG12345_LoginScreenCrash() {
        // Comment: This test verifies fix for bug #12345
        XCTAssertTrue(true)
    }

    // Workaround 2: XCTest does support expected failures, but with less flexibility
    func testKnownIssueInXCTest() {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issue.type == .assertionFailure
        }

        XCTExpectFailure("Button animation is broken", options: options) {
            XCTAssertTrue(false) // This assertion will fail
        }
    }

    // LIMITATIONS OF XCTEST APPROACHES:
    // 1. No direct connection between tests and bug tracking systems
    // 2. Can't filter or select tests based on bug IDs or URLs
    // 3. No automatic tracking of which tests verify which bug fixes
    // 4. Less flexible expected failure handling
    // 5. No standard way to generate reports of fixed bugs for release notes
    // 6. No way to associate multiple bugs with a single test
}

// ===========================================================================================
// 7. INTEGRATING WITH CI/CD AND ISSUE TRACKING
// ===========================================================================================

struct CIIntegrationExamples {
    // Example of bug traits that integrate with CI/CD workflows

    // Tests that must pass before release
    @Test(.bug("Critical security vulnerability", id: "SEC-123"))
    func testSecurityFix() {
        // Test verifying important security fix
        #expect(true)
    }

    // Automatically update issue trackers based on test results
    @Test(.bug("https://jira.example.com/browse/ISSUE-456"))
    func testJiraIssue() {
        // CI system can update the linked Jira issue when this test passes
        #expect(true)
    }

    // Generate release notes automatically
    @Suite(.bug("Release 2.0 bug fixes"))
    struct Release2_0Fixes {
        @Test(.bug(id: "UI-123"))
        func testFixedUIBug() {
            #expect(true)
        }

        @Test(.bug(id: "PERF-456"))
        func testFixedPerformanceBug() {
            #expect(true)
        }

        // CI/CD systems can generate release notes by collecting all bug fixes
        // verified by passing tests in this suite
    }
}

// ===========================================================================================
// CONCLUSION
// ===========================================================================================
//
// Swift Testing's bug trait system provides significant advantages:
//
// 1. TRACEABILITY: Direct connection between tests and bug tracking systems
// 2. DOCUMENTATION: Self-documenting tests that explain what bugs they verify
// 3. REPORTING: Easy generation of fixed bug reports for release notes
// 4. INTELLIGENCE: Tests understand which failures are expected vs unexpected
// 5. WORKFLOW: Improved integration with development and QA processes
//
// This creates a more cohesive connection between your test suite and your
// software development lifecycle, making it easier to track progress and
// ensure that fixed bugs stay fixed.

//@Test
//func testCommentInputFieldVisibility() {
//    // Check if we're running on an iPhone (small screen)
//    let isIPhone = UIDevice.current.userInterfaceIdiom == .phone
//
//    withKnownIssue("Comment field gets hidden by keyboard on iPhone only") {
//        // Setup test scenario
//        let commentView = CommentInputView()
//        commentView.activateKeyboard()
//
//        // On iPhone, the comment field is partially obscured by the keyboard
//        // but works correctly on iPad due to larger screen size
//        #expect(commentView.isFullyVisible)
//    } when: {
//        // Only consider this a known issue when running on iPhone
//        isIPhone
//    }
//
//    // Other assertions that should pass on all devices continue...
//    #expect(commentView.canAcceptInput)
//}
//
//@Test
//func testCommentInputFieldVisibility() {
//    let isIPhone = UIDevice.current.userInterfaceIdiom == .phone
//
//    withKnownIssue("Comment field gets hidden by keyboard on iPhone only") {
//        let commentView = CommentInputView()
//        commentView.activateKeyboard()
//        #expect(commentView.isFullyVisible)
//    } when: {
//        isIPhone
//    }
//
//    #expect(commentView.canAcceptInput)
//}


// Real bug that cost us $50k in lost revenue last quarter when customers
// with apostrophes in their names couldn't complete transactions
//@Test(.bug("https://github.com/myorg/myrepo/issues/789"))
//func testNameWithSpecialCharacters() {
//    let processor = PaymentProcessor()
//    let payment = Payment(customerName: "O'Reilly", amount: 99.99)
//    let result = processor.processPayment(payment)
//    #expect(result.succeeded)
//}
//
//static func bug(
//    _ url: String,
//    _ title: Comment? = nil
//) -> Bug

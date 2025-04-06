import Testing
import XCTest
@testable import GithubExplorerTest

// ===========================================================================================
//
//  SWIFT TESTING COMPLETION HANDLERS GUIDE
//  ---------------------------------------
//
//  This guide demonstrates techniques for testing traditional completion handler-based APIs
//  with both XCTest and Swift Testing, showing how to handle success, errors, and cancellation.
//
// ===========================================================================================

/*
 COMPLETION HANDLER TESTING CHALLENGES

 Testing code that uses completion handlers presents unique challenges:

 1. ASYNCHRONOUS VERIFICATION
    - Need to wait for completion handlers to be called
    - Verify that callbacks are executed with correct parameters
    - Handle timeouts appropriately when callbacks aren't called

 2. ERROR HANDLING
    - Test both success and error cases
    - Ensure errors are properly propagated
    - Verify error types and contents

 3. CANCELLATION TESTING
    - Verify that callbacks are NOT called after cancellation
    - Avoid false positives in negative testing
    - Ensure proper cleanup after cancellation

 4. CONVERSION TO STRUCTURED CONCURRENCY
    - Convert callback-based APIs to async/await for easier testing
    - Handle conversions that might throw errors
    - Maintain proper error propagation when converting
 */

// ===========================================================================================
//  TESTING COMPLETION HANDLERS
// ===========================================================================================

// A service that uses traditional completion handlers
class CompletionHandlerService {
    func fetchData(completion: @escaping (Result<String, Error>) -> Void) {
        // Simulate async work
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            completion(.success("Data fetched successfully"))
        }
    }

    func fetchWithError(completion: @escaping (Result<String, Error>) -> Void) {
        // Simulate async work with error
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let error = NSError(domain: "CompletionHandlerService", code: 500,
                               userInfo: [NSLocalizedDescriptionKey: "Network error"])
            completion(.failure(error))
        }
    }

    // Sometimes we need to test that a completion is NOT called
    func cancelableOperation(id: String, completion: @escaping (String) -> Void) -> () -> Void {
        let task = DispatchWorkItem {
            completion("Completed \(id)")
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5, execute: task)

        // Return a cancel function
        return {
            task.cancel()
        }
    }
}

// -----------------------------------------------------------------------------------------
// XCTEST APPROACH
// -----------------------------------------------------------------------------------------

class CompletionHandlerXCTests: XCTestCase {
    let service = CompletionHandlerService()

    func test_FetchingData_Is_Successful() {
        let service = CompletionHandlerService()
        let expectation = self.expectation(description: "Fetch data")
        var fetchedData: String?

        service.fetchData { result in
            switch result {
            case .success(let data):
                fetchedData = data
            case .failure:
                XCTFail("Unexpected error")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(fetchedData, "Data fetched successfully")
    }

    func testFetchingDataIsSuccessful() {
        // GIVEN: A CompletionHandlerService that provides data fetching capabilities
        let service = CompletionHandlerService() // SUT clearly identified
        let expectation = self.expectation(description: "Fetch data")
        var fetchedData: String?

        // WHEN: We fetch data using a completion handler
        service.fetchData { result in
            switch result {
            case .success(let data):
                fetchedData = data
            case .failure:
                XCTFail("Unexpected error")
            }
            expectation.fulfill()
        }

        // THEN: We should receive the expected data
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(fetchedData, "Data fetched successfully")
    }

    func testFetchWithError() {
        // GIVEN: A CompletionHandlerService that will return an error
        let completionHandlerService = service // SUT clearly identified
        let expectation = self.expectation(description: "Fetch with error")
        var receivedError: Error?

        // WHEN: We attempt to fetch data that will result in an error
        completionHandlerService.fetchWithError { result in
            switch result {
            case .success:
                XCTFail("Expected error but got success")
            case .failure(let error):
                receivedError = error
            }
            expectation.fulfill()
        }

        // THEN: We should receive the expected error
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedError)
        XCTAssertEqual((receivedError as? NSError)?.code, 500)
    }

    func testCompletionNotCalled() {
        // GIVEN: A CompletionHandlerService with a cancelable operation
        let completionHandlerService = service // SUT clearly identified
        let expectation = self.expectation(description: "Operation should not complete")
        expectation.isInverted = true // This is key - we expect this NOT to be fulfilled

        // WHEN: We start an operation but immediately cancel it
        let cancel = completionHandlerService.cancelableOperation(id: "test") { _ in
            expectation.fulfill() // This should not be called
        }

        // Cancel immediately
        cancel()

        // THEN: The completion handler should not be called
        waitForExpectations(timeout: 1.0)
    }
}

// -----------------------------------------------------------------------------------------
// SWIFT TESTING APPROACH
// -----------------------------------------------------------------------------------------

struct CompletionHandlerTests {
    let service = CompletionHandlerService()

    @Test func fetchDataIsSuccessful() async {
        // GIVEN: A CompletionHandlerService that provides data fetching capabilities
        let completionHandlerService = service // SUT clearly identified
        var fetchedData: String?

        // WHEN: We fetch data using a completion handler converted to async
        let result = await withCheckedContinuation { continuation in
            completionHandlerService.fetchData { result in
                continuation.resume(returning: result)
            }
        }

        // THEN: We should receive the expected data
        switch result {
        case .success(let data):
            fetchedData = data
        case .failure(let error):
            Issue.record("Expected Success but got error: \(error)")
        }

        #expect(fetchedData == "Data fetched successfully")
    }

    @Test func fetchWithError() async {
        // GIVEN: A CompletionHandlerService that will return an error
        let completionHandlerService = service // SUT clearly identified

        // WHEN: We attempt to fetch data that will result in an error
        do {
            let data = try await withCheckedThrowingContinuation { continuation in
                completionHandlerService.fetchWithError { result in
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            Issue.record("Expected error but got success with data: \(data)")
        } catch {
            // THEN: We should receive the expected error
            #expect((error as NSError).code == 500)
        }
    }

    @Test func completionNotCalled() async {
        // GIVEN: A CompletionHandlerService with a cancelable operation
        let completionHandlerService = service // SUT clearly identified

        // WHEN/THEN: We start an operation, cancel it, and verify the callback isn't called
        await confirmation(expectedCount: 0) { confirmation in
            let cancel = completionHandlerService.cancelableOperation(id: "test") { _ in
                confirmation()
            }

            // Cancel immediately
            cancel()

            // Wait enough time for the operation to have completed if not cancelled
            try? await Task.sleep(for: .milliseconds(600))
        }
    }
}

// ===========================================================================================
//  ADVANCED EXAMPLE: CALLBACKS WITH NOTIFICATIONS
// ===========================================================================================

// A service that uses callback and notifications
class NotificationService {
    var handler: ((String) -> Void)? = nil

    func registerForNotifications(handler: @escaping (String) -> Void) {
        self.handler = handler
    }

    func simulatePushNotification() async {
        // Simulate delay before notification arrives
        try? await Task.sleep(for: .milliseconds(200))
        handler?("New notification")
    }
}

// -----------------------------------------------------------------------------------------
// XCTEST APPROACH
// -----------------------------------------------------------------------------------------

class NotificationServiceXCTests: XCTestCase {
    let service = NotificationService()

    func testNotification() async {
        // GIVEN: A NotificationService that can send notifications
        let notificationService = service // SUT clearly identified
        let expectation = self.expectation(description: "Received notification")

        // WHEN: We register for notifications and a notification is sent
        notificationService.registerForNotifications { message in
            XCTAssertEqual(message, "New notification")
            expectation.fulfill()
        }

        // Start the async process
        Task {
            await notificationService.simulatePushNotification()
        }

        // THEN: We should receive the notification with the expected message
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}

// -----------------------------------------------------------------------------------------
// SWIFT TESTING APPROACH
// -----------------------------------------------------------------------------------------

struct NotificationServiceTests {
    let service = NotificationService()

    @Test func receivesNotification() async {
        // GIVEN: A NotificationService that can send notifications
        let notificationService = service // SUT clearly identified

        // WHEN/THEN: We register for notifications and verify the notification is received
        await confirmation { notificationReceived in
            notificationService.registerForNotifications { message in
                #expect(message == "New notification")
                notificationReceived() // Mark the confirmation as successful
            }

            await notificationService.simulatePushNotification()
        }
    }

    @Test func confirmationWithCount() async {
        // GIVEN: A NotificationService that can send multiple notifications
        let notificationService = service // SUT clearly identified

        // WHEN/THEN: We register for notifications and verify multiple notifications are received
        await confirmation(expectedCount: 2) { notificationReceived in
            notificationService.registerForNotifications { _ in
                notificationReceived()
            }

            // Simulate two notifications - await them to ensure they complete
            await notificationService.simulatePushNotification()
            await notificationService.simulatePushNotification()
        }
    }
}

// ===========================================================================================
//  BEST PRACTICES FOR COMPLETION HANDLER TESTING
// ===========================================================================================

/*
 COMPLETION HANDLER TESTING BEST PRACTICES:

 1. CONVERT TO ASYNC/AWAIT WHEN POSSIBLE
    - Use withCheckedContinuation for simple completions
    - Use withCheckedThrowingContinuation for error handling
    - Be careful about one-shot vs. repeated callbacks

 2. USE PROPER TIMEOUT VALUES
    - Set reasonable timeouts for expectations
    - Avoid too short timeouts that cause flaky tests
    - Avoid too long timeouts that slow down your test suite

 3. TEST NEGATIVE CASES
    - Use inverted expectations in XCTest to verify callbacks aren't called
    - Use confirmation with expectedCount: 0 in Swift Testing
    - Always include a timeout long enough for the operation to have completed

 4. HANDLE MULTIPLE CALLBACKS
    - Track callback count when needed
    - Test order of callbacks when relevant
    - Use expectedFulfillmentCount in XCTest or expectedCount in Swift Testing

 5. CLEAN UP RESOURCES
    - Make sure to unregister from notifications/callbacks when done
    - Test that cleanup happens properly
    - Ensure test state doesn't leak between tests
 */

// ===========================================================================================
//  README: COMPLETION HANDLER TESTING WITH SUT AND GIVEN-WHEN-THEN APPROACH
// ===========================================================================================

/*
 COMPLETION HANDLER TESTING WITH SUT AND GIVEN-WHEN-THEN:

 1. SYSTEM UNDER TEST (SUT) PATTERN
    - Clearly identify what component is being tested (the System Under Test)
    - Make the SUT explicit in your test method to clarify what's being tested
    - Focus each test on a single responsibility of the SUT
    - Use descriptive variable names that indicate the SUT role

 2. GIVEN-WHEN-THEN STRUCTURE
    - GIVEN: Set up the test environment and preconditions
      * Initialize the SUT with known state
      * Prepare any expectations or continuations needed
      * Set up the completion handlers

    - WHEN: Perform the action being tested
      * Call the async method with completion handler
      * Trigger the operation that will eventually call the completion handler
      * For cancellation tests, call the cancel function

    - THEN: Verify the expected outcomes
      * Verify the completion handler was called with expected values
      * For error tests, verify the correct error was received
      * For cancellation tests, verify the completion handler was NOT called

 3. HANDLING ASYNCHRONOUS COMPLETION
    - In XCTest: Use expectations and waitForExpectations
    - In Swift Testing: Use withCheckedContinuation or confirmation
    - For negative testing (verifying something doesn't happen):
      * XCTest: Use inverted expectations
      * Swift Testing: Use confirmation with expectedCount: 0

 4. CONVERSION TO STRUCTURED CONCURRENCY
    - Convert callbacks to async/await using withCheckedContinuation
    - Handle errors with withCheckedThrowingContinuation
    - This simplifies the test and makes it more readable
 */

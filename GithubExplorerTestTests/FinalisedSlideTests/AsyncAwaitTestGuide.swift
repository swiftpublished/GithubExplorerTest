import Testing
import XCTest
@testable import GithubExplorerTest

// ===========================================================================================
//
//  SWIFT TESTING ASYNC/AWAIT GUIDE
//  -------------------------------
//
//  This guide focuses on basic async/await testing and monitoring state changes
//  in asynchronous code with practical examples comparing XCTest and Swift Testing.
//
// ===========================================================================================

/*
 BASIC ASYNC/AWAIT TESTING

 Testing asynchronous code with async/await presents several advantages:

 1. DIRECT INTEGRATION
    - Mark test functions as async for natural suspension points
    - Use await to directly wait for asynchronous results
    - Clear error propagation with try/catch

 2. STATE VERIFICATION
    - Test intermediate and final states after async operations
    - Monitor changes over time in a structured way
    - Ensure proper state transitions during async processes

 3. TIMEOUT HANDLING
    - More reliable than fixed timeouts with expectations
    - Structure-based waiting instead of arbitrary timing
    - Better diagnostics when operations don't complete
 */

// ===========================================================================================
//  BASIC ASYNCHRONOUS TESTING EXAMPLE
// ===========================================================================================

// Define a model type for user data
struct AsyncUserObject: Equatable {
    let id: Int
    let name: String
    let email: String
}

// Define a protocol for the service we want to test
protocol UserServiceProtocol {
    func getUser(id: Int) -> AsyncUserObject
}

// A simple async service to test
class AsyncUserService {
    func fetchUserName(id: Int) async throws -> String {
        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(100))

        if id < 0 {
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }

        return "User \(id)"
    }
}

// A synchronous implementation of the UserServiceProtocol
class SyncUserService: UserServiceProtocol {
    func getUser(id: Int) -> AsyncUserObject {
        // This would typically retrieve data from a database or cache
        return AsyncUserObject(
            id: id,
            name: "User \(id)",
            email: "user\(id)@example.com"
        )
    }
}

// -----------------------------------------------------------------------------------------
// XCTEST APPROACH
// -----------------------------------------------------------------------------------------

class UserServiceXCTests: XCTestCase {
    let service = AsyncUserService()

    // Testing successful async operation
    func testFetchUserName() async throws {
        let userName = try await service.fetchUserName(id: 1)
        XCTAssertEqual(userName, "User 1")
    }

    // Testing errors in async operation
    func testFetchUserNameError() async {
        do {
            _ = try await service.fetchUserName(id: -1)
            XCTFail("Expected error not thrown")
        } catch {
            // Test passes if error was thrown
            XCTAssertTrue(true)
        }
    }

    // Testing with expectations (old style with async/await)
    /*
    func testFetchUserNameWithExpectation() {
        let expectation = self.expectation(description: "Fetch user name")

        Task {
            do {
                let userName = try await service.fetchUserName(id: 1)
                XCTFail("Expected error not thrown")
                expectation.fulfill()
            } catch {
                XCTFail("Unexpected error: \(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }
     */

    func test_Fetch_UserName_Throws_For_InvalidId() {
        let expectation = self.expectation(description: "Fetch user name")

        Task {
            do {
                let userName = try await service.fetchUserName(id: -1)
                XCTFail("Expected error not thrown")
                expectation.fulfill()
            } catch let error {
                XCTAssertNotNil(error)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }
}

// -----------------------------------------------------------------------------------------
// SWIFT TESTING APPROACH
// -----------------------------------------------------------------------------------------

struct AsyncUserServiceTests {
    let service = AsyncUserService()

    // Testing successful async operation - cleaner syntax
    @Test func fetchUserName() async throws {
        let userName = try await service.fetchUserName(id: 1)
        #expect(userName == "User 1")
    }

    // Testing errors in async operation - more expressive
//    @Test func fetchUserNameThrowsForInvalidId() async {
//        await #expect(throws: NSError.self) {
//            _ = try await service.fetchUserName(id: -1)
//        }
//    }

    // No need for expectations for simple async calls!
}

// ===========================================================================================
//  CHECKING FOR CHANGES IN ASYNC CODE
// ===========================================================================================

// A class with observable state
class ObservableStateManager {
    private(set) var state: String = "initial"
    private var observers: [(String) -> Void] = []

    func addObserver(_ handler: @escaping (String) -> Void) {
        observers.append(handler)
    }

    func updateState(to newState: String) async {
        // Simulate work
        try? await Task.sleep(for: .milliseconds(100))
        state = newState

        // Notify observers
        for observer in observers {
            observer(newState)
        }
    }
}

// -----------------------------------------------------------------------------------------
// XCTEST APPROACH
// -----------------------------------------------------------------------------------------

class StateChangeXCTests: XCTestCase {
    func testStateChange() async {
        let manager = ObservableStateManager()

        // Initial state check
        XCTAssertEqual(manager.state, "initial")

        // Track changes with expectation
        let expectation = self.expectation(description: "State changed")
        manager.addObserver { newState in
            XCTAssertEqual(newState, "updated")
            expectation.fulfill()
        }

        // Trigger state change
        Task {
            await manager.updateState(to: "updated")
        }

        // Wait for the change notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Verify final state
        XCTAssertEqual(manager.state, "updated")
    }

    func testMultipleStateChanges() async {
        let manager = ObservableStateManager()
        var stateHistory: [String] = []

        // Set up to track all state changes
        let expectation = self.expectation(description: "All states observed")
        expectation.expectedFulfillmentCount = 2

        manager.addObserver { newState in
            stateHistory.append(newState)
            expectation.fulfill()
        }

        // Trigger multiple state changes
        Task {
            await manager.updateState(to: "in progress")
            await manager.updateState(to: "completed")
        }

        // Wait for all changes
        await fulfillment(of: [expectation], timeout: 2.0)

        // Verify state history
        XCTAssertEqual(stateHistory, ["in progress", "completed"])
        XCTAssertEqual(manager.state, "completed")
    }
}

// -----------------------------------------------------------------------------------------
// SWIFT TESTING APPROACH
// -----------------------------------------------------------------------------------------

struct StateChangeTests {
    @Test func stateChange() async {
        let manager = ObservableStateManager()

        // Initial state check
        #expect(manager.state == "initial")

        // Use confirmation to track the change
        await confirmation { stateChanged in
            manager.addObserver { newState in
                #expect(newState == "updated")
                stateChanged()
            }

            await manager.updateState(to: "updated")
        }

        // Verify final state
        #expect(manager.state == "updated")
    }

    @Test func multipleStateChanges() async {
        let manager = ObservableStateManager()
        var stateHistory: [String] = []

        // Use confirmation with expected count
        await confirmation(expectedCount: 2) { stateChanged in
            manager.addObserver { newState in
                stateHistory.append(newState)
                stateChanged()
            }

            // Directly await state changes
            await manager.updateState(to: "in progress")
            await manager.updateState(to: "completed")
        }

        // Verify state history
        #expect(stateHistory == ["in progress", "completed"])
        #expect(manager.state == "completed")
    }
}

// ===========================================================================================
//  BEST PRACTICES FOR ASYNC/AWAIT TESTING
// ===========================================================================================

/*
 ASYNC/AWAIT TESTING BEST PRACTICES:

 1. USE DIRECT ASYNC SYNTAX
    - Mark test functions as async when testing async code
    - Use await directly instead of expectation-based patterns
    - Let Swift's type system guide your test structure

 2. STRUCTURE ERROR HANDLING PROPERLY
    - Use try/catch for expected errors
    - Use Swift Testing's #expect(throws:) for cleaner error testing
    - Test both success and error paths

 3. AVOID ARBITRARY TIMEOUTS
    - Structure your tests to wait for specific events
    - Use confirmations for callback-based code
    - Don't rely on sleep or fixed delays

 4. TEST STATE TRANSITIONS
    - Verify initial, intermediate, and final states
    - Use observers to track state changes
    - Test with multiple state transitions

 5. LEVERAGE SWIFT CONCURRENCY
    - Use async let for concurrent operations
    - Test with Task for background work
    - Consider task priorities for timing-sensitive tests
 */

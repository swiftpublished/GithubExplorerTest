import Testing
import XCTest
@testable import GithubExplorerTest

// ===========================================================================================
// PARALLELIZATION TRAITS IN SWIFT TESTING
// ===========================================================================================

// A mock class representing a database connection that's shared across tests
class SharedDatabaseConnection {
    static let shared = SharedDatabaseConnection()

    private var isInTransaction = false
    private var userRecords: [String: String] = [
        "user1": "Alice",
        "user2": "Bob",
        "user3": "Charlie"
    ]

    // Simulates beginning a database transaction
    func beginTransaction() async throws {
        // In a real database, transactions lock tables and need exclusive access
        if isInTransaction {
            throw DatabaseError.alreadyInTransaction
        }

        // Simulate some work
        try await Task.sleep(for: .milliseconds(100))
        isInTransaction = true
    }

    // Simulates committing a transaction
    func commitTransaction() async throws {
        guard isInTransaction else {
            throw DatabaseError.noActiveTransaction
        }

        // Simulate some work
        try await Task.sleep(for: .milliseconds(100))
        isInTransaction = false
    }

    // Read a user record
    func getUser(id: String) async throws -> String? {
        // Simulate network/disk latency
        try await Task.sleep(for: .milliseconds(50))
        return userRecords[id]
    }

    // Update a user record (requires transaction)
    func updateUser(id: String, name: String) async throws {
        guard isInTransaction else {
            throw DatabaseError.operationRequiresTransaction
        }

        // Simulate work
        try await Task.sleep(for: .milliseconds(150))
        userRecords[id] = name
    }

    // Reset the database state between tests
    func reset() {
        isInTransaction = false
        userRecords = [
            "user1": "Alice",
            "user2": "Bob",
            "user3": "Charlie"
        ]
    }

    enum DatabaseError: Error {
        case alreadyInTransaction
        case noActiveTransaction
        case operationRequiresTransaction
    }
}

// Define a simple struct for parameterized test demonstration
struct UserUpdate {
    let id: String
    let newName: String

    static let updates: [UserUpdate] = [
        UserUpdate(id: "user1", newName: "Alicia"),
        UserUpdate(id: "user2", newName: "Robert"),
        UserUpdate(id: "user3", newName: "Charles")
    ]
}

// ===========================================================================================
// Swift Testing Example - Using Parallelization Traits CORRECTLY
// ===========================================================================================

// Example 1: Using .serialized with parameterized tests
struct ParameterizedDatabaseTests {

    // Setup before each test
    func setup() async {
        SharedDatabaseConnection.shared.reset()
    }

    // CORRECT USAGE 1: Parameterized test with .serialized trait
    // This will run each test case (each update) serially instead of in parallel
    @Test(.disabled(), .serialized, arguments: UserUpdate.updates)
    func updateUserWithTransaction(update: UserUpdate) async throws {
        await setup()

        let db = SharedDatabaseConnection.shared

        // Start a transaction
        try await db.beginTransaction()

        // Update a user
        try await db.updateUser(id: update.id, name: update.newName)

        // Commit the transaction
        try await db.commitTransaction()

        // Verify the update
        let updatedUser = try await db.getUser(id: update.id)
        #expect(updatedUser == update.newName)
    }

    // For comparison: Without .serialized, these would run in parallel
    // which could cause conflicts since they all use the same shared database
    @Test(arguments: UserUpdate.updates)
    func readUser(update: UserUpdate) async throws {
        // Read operations don't need transactions, so they're fine to run in parallel
        let user = try await SharedDatabaseConnection.shared.getUser(id: update.id)
        #expect(user != nil)
    }
}

// CORRECT USAGE 2: Suite with .serialized trait
// This causes all tests in the suite to run serially, not in parallel
@Suite(.serialized, .disabled())
struct SerializedDatabaseTestSuite {
    // Setup before each test
    func setup() async {
        SharedDatabaseConnection.shared.reset()
    }

    // These tests will run one after another, not concurrently
    // because the entire suite has the .serialized trait

    @Test
    func test1_beginTransaction() async throws {
        await setup()
        try await SharedDatabaseConnection.shared.beginTransaction()
        #expect(true)
    }

    @Test
    func test2_updateUser() async throws {
        // This won't run until test1 is complete
        try await SharedDatabaseConnection.shared.updateUser(id: "user1", name: "Updated")
        #expect(true)
    }

    @Test
    func test3_commitTransaction() async throws {
        // This won't run until test2 is complete
        try await SharedDatabaseConnection.shared.commitTransaction()
        #expect(true)
    }

    @Test
    func test4_verifyUpdate() async throws {
        // This won't run until test3 is complete
        let user = try await SharedDatabaseConnection.shared.getUser(id: "user1")
        #expect(user == "Updated")
    }
}

// Example of INCORRECT usage (what we had before):
// .serialized has NO EFFECT on non-parameterized test functions
struct IncorrectUsageExample {
    @Test(.serialized) // Warning: This has no effect!
    func thisTraitHasNoEffect() async {
        // The .serialized trait does nothing here since this is not
        // a parameterized test and not a suite
        #expect(true)
    }
}

// ===========================================================================================
// XCTest Comparison - Handling Test Parallelization
// ===========================================================================================

// In XCTest, controlling parallel execution is more manual and limited
class DatabaseTestsXCTest: XCTestCase {

    override func setUp() {
        super.setUp()
        SharedDatabaseConnection.shared.reset()
    }

    // XCTest doesn't have built-in traits for controlling parallelization
    // You can set up test plans in Xcode with execution options
    // or control it at the scheme level, but not per-test

    // To achieve similar functionality to Swift Testing's parameterized tests
    // with .serialized, you'd need to write separate tests or use a loop
    func testUpdateMultipleUsers() async throws {
        let updates = [
            ("user1", "Alicia"),
            ("user2", "Robert"),
            ("user3", "Charles")
        ]

        let db = SharedDatabaseConnection.shared

        // Process updates one at a time (serially)
        for (userId, newName) in updates {
            // Start a transaction
            try await db.beginTransaction()

            // Update a user
            try await db.updateUser(id: userId, name: newName)

            // Commit the transaction
            try await db.commitTransaction()

            // Verify the update
            let updatedUser = try await db.getUser(id: userId)
            XCTAssertEqual(updatedUser, newName)
        }
    }
}

@Suite(.serialized)
struct DBTests {
    func setup() async {
        SharedDatabaseConnection.shared.reset()
    }

    @Test
    func test1_beginTransaction() async throws {
        await setup()
        try await SharedDatabaseConnection.shared.beginTransaction()
        #expect(true)
    }

    // This won't run until test1 is complete
    @Test
    func test2_updateUser() async throws {
        try await SharedDatabaseConnection.shared.updateUser(id: "user1", name: "Updated")
        #expect(true)
    }

    // This won't run until test2 is complete
    @Test
    func test3_commitTransaction() async throws {
        try await SharedDatabaseConnection.shared.commitTransaction()
        #expect(true)
    }

    // This won't run until test3 is complete
    @Test
    func test4_verifyUpdate() async throws {
        let user = try await SharedDatabaseConnection.shared.getUser(id: "user1")
        #expect(user == "Updated")
    }
}

// These tests will run one after another,
// Not concurrently
// Because the entire suite has the .serialized trait


struct IncorrectUsageExample2 {
    @Test(.serialized)
    func thisTraitHasNoEffect() async {
        #expect(true)
    }
}

// Warning: This has no effect!

// The .serialized trait does nothing here since this is not
// a parameterized test and not a suite

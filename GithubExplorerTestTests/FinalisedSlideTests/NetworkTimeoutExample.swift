import Testing
import XCTest
@testable import GithubExplorerTest

// ===========================================================================================
// PRACTICAL TIMEOUT TESTING EXAMPLES (WITHOUT REAL NETWORK REQUESTS)
// ===========================================================================================

// Mock data processor that simulates async operations
class DataProcessor {
    // Simulates loading a large dataset
    func loadLargeDataset() async throws -> [Int] {
        // Simulate work with delay
        try await Task.sleep(for: .milliseconds(200))
        return Array(1...10000)
    }

    // Performs complex filtering operation
    func filterPrimeNumbers(from numbers: [Int]) async throws -> [Int] {
        // Simulate a complex operation that could potentially take too long
        try await Task.sleep(for: .milliseconds(300))

        return try await withThrowingTaskGroup(of: [Int].self) { group in
            let chunkSize = 1000
            var result = [Int]()

            // Split work into chunks for parallel processing
            for i in stride(from: 0, to: numbers.count, by: chunkSize) {
                let end = min(i + chunkSize, numbers.count)
                let chunk = Array(numbers[i..<end])

                group.addTask {
                    // Filter primes (simplified for demo)
                    return chunk.filter { num in
                        if num <= 1 { return false }
                        if num <= 3 { return true }
                        if num % 2 == 0 || num % 3 == 0 { return false }
                        var i = 5
                        while i * i <= num {
                            if num % i == 0 || num % (i + 2) == 0 { return false }
                            i += 6
                        }
                        return true
                    }
                }
            }

            // Collect results
            for try await primes in group {
                result.append(contentsOf: primes)
            }

            return result.sorted()
        }
    }

    // Method that could hang or timeout
    func processDatasetWithPotentialDelay(delaySeconds: Double = 0) async throws -> [Int] {
        let data = try await loadLargeDataset()

        // Simulate a potential hang or bug that causes excessive delay
        if delaySeconds > 0 {
            try await Task.sleep(for: .seconds(delaySeconds))
        }

        return try await filterPrimeNumbers(from: data)
    }
}

// ---------------------------------------------------------------------------------
// XCTest Example - Timeout Testing with Local Processing
// ---------------------------------------------------------------------------------
class LocalProcessingTimeoutXCTest: XCTestCase {

    // Test with XCTest expectation timeout
    func testDataProcessingTimeout() {
        // Create an expectation for the async operation
        let expectation = XCTestExpectation(description: "Data processing completed")

        // Create the processor
        let processor = DataProcessor()

        // Start the task
        Task {
            do {
                // This should process quickly (no artificial delay)
                let result = try await processor.processDatasetWithPotentialDelay()
                XCTAssertTrue(result.count > 0, "Should find some prime numbers")
                expectation.fulfill()
            } catch {
                XCTFail("Processing failed: \(error.localizedDescription)")
            }
        }

        // Wait with timeout - operation should complete within 2 seconds
        wait(for: [expectation], timeout: 2.0)
    }
}

// ---------------------------------------------------------------------------------
// Swift Testing Example - Timeout Testing with Local Processing
// ---------------------------------------------------------------------------------
struct LocalProcessingSwiftTesting {

    // Test with Swift Testing's timeLimit trait
    @Test(.timeLimit(.minutes(1)))
    func testDataProcessing() async throws {
        // Create the processor
        let processor = DataProcessor()

        // Perform the operation - Swift Testing will enforce the time limit
        let result = try await processor.processDatasetWithPotentialDelay()

        // Assert expected results
        #expect(result.count > 0, "Should find some prime numbers")
    }
}


struct LocalProcessingSwiftTesting2 {
    @Test(.timeLimit(.minutes(1)))
    func testDataProcessing() async throws {
        let processor = DataProcessor()
        let result = try await processor.processDatasetWithPotentialDelay()
        #expect(result.count > 0, "Should find some prime numbers")
    }
}


class LocalProcessingTimeoutXCTest2: XCTestCase {
    func testDataProcessingTimeout() {
        let expectation = XCTestExpectation(description: "Data processing completed")
        let processor = DataProcessor()
        Task {
            do {
                let result = try await processor.processDatasetWithPotentialDelay()
                XCTAssertTrue(result.count > 0, "Should find some prime numbers")
                expectation.fulfill()
            } catch {
                XCTFail("Processing failed: \(error.localizedDescription)")
            }
        }
        wait(for: [expectation], timeout: 2.1)
    }
}


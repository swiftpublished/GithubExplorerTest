import Testing
import XCTest
import Combine
@testable import GithubExplorerTest

// ===========================================================================================
//
//  SWIFT TESTING ASYNCSEQUENCE GUIDE
//  ---------------------------------
//
//  This guide demonstrates techniques for testing AsyncSequence and AsyncStream
//  with both XCTest and Swift Testing, including handling errors and early termination.
//
// ===========================================================================================

/*
 ASYNCSEQUENCE TESTING CHALLENGES

 Testing code that uses AsyncSequence presents unique challenges:

 1. ASYNCHRONOUS ITERATION
    - Handling the await points in for-await-in loops
    - Collecting values from asynchronous streams
    - Testing early termination of sequences

 2. ERROR HANDLING
    - Testing sequences that throw errors
    - Verifying correct error propagation
    - Testing partial consumption before errors

 3. BACKPRESSURE AND TIMING
    - Testing sequences with variable timing
    - Handling sequences that may produce values at different rates
    - Dealing with sequences that buffer values

 4. CANCELLATION
    - Testing proper cancellation of AsyncSequence consumption
    - Verifying resources are cleaned up after cancellation
    - Testing partial consumption with cancellation
 */

// ===========================================================================================
//  TESTING ASYNCSEQUENCE AND ASYNCSTREAM
// ===========================================================================================

// A service that produces an AsyncSequence
class AsyncSequenceService {
    // Produce a sequence of integers with delays
    func countSequence() -> AsyncStream<Int> {
        return AsyncStream { continuation in
            Task {
                for i in 1...5 {
                    try? await Task.sleep(for: .milliseconds(50))
                    continuation.yield(i)
                }
                continuation.finish()
            }
        }
    }

    // Produce events that can be observed with AsyncStream
    func eventStream() -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                continuation.yield("start")
                try? await Task.sleep(for: .milliseconds(100))
                continuation.yield("processing")
                try? await Task.sleep(for: .milliseconds(100))
                continuation.yield("complete")
                continuation.finish()
            }
        }
    }

    // An example that throws errors
    func erroringSequence() -> AsyncThrowingStream<Int, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                for i in 1...3 {
                    try? await Task.sleep(for: .milliseconds(50))
                    continuation.yield(i)
                }

                // Throw an error at the end
                continuation.finish(throwing: NSError(domain: "AsyncSequenceService", code: 400,
                                   userInfo: [NSLocalizedDescriptionKey: "Sequence error"]))
            }
        }
    }
}

// -----------------------------------------------------------------------------------------
// XCTEST APPROACH
// -----------------------------------------------------------------------------------------

class AsyncSequenceXCTests: XCTestCase {
    let service = AsyncSequenceService()

    func testCountSequence() async {
        // GIVEN: An AsyncSequenceService that produces a sequence of integers
        let asyncSequenceService = service // SUT clearly identified
        var values: [Int] = []

        // WHEN: We collect values from the AsyncSequence
        for await value in asyncSequenceService.countSequence() {
            values.append(value)
        }

        // THEN: We should receive the expected sequence of values
        XCTAssertEqual(values, [1, 2, 3, 4, 5])
    }

    func testEventStream() async {
        // GIVEN: An AsyncSequenceService that produces a stream of events
        let asyncSequenceService = service // SUT clearly identified
        let expectation = self.expectation(description: "Event stream complete")
        var events: [String] = []

        // WHEN: We start a task to collect events
        Task {
            for await event in asyncSequenceService.eventStream() {
                events.append(event)
            }
            expectation.fulfill()
        }

        // THEN: We should receive all expected events in the correct order
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(events, ["start", "processing", "complete"])
    }

    func testErroringSequence() async {
        // GIVEN: An AsyncSequenceService that produces a sequence that ends with an error
        let asyncSequenceService = service // SUT clearly identified
        var values: [Int] = []
        var caughtError: Error?

        // WHEN: We iterate through the sequence and handle the error
        do {
            for try await value in asyncSequenceService.erroringSequence() {
                values.append(value)
            }
        } catch {
            caughtError = error
        }

        // THEN: We should receive the expected values and error
        XCTAssertEqual(values, [1, 2, 3])
        XCTAssertNotNil(caughtError)
        XCTAssertEqual((caughtError as? NSError)?.code, 400)
    }
}

// -----------------------------------------------------------------------------------------
// SWIFT TESTING APPROACH
// -----------------------------------------------------------------------------------------

struct AsyncSequenceTests {
    let service = AsyncSequenceService()

    @Test func countSequence() async {
        // GIVEN: An AsyncSequenceService that produces a sequence of integers
        let asyncSequenceService = service // SUT clearly identified
        var values: [Int] = []

        // WHEN: We collect values from the AsyncSequence
        for await value in asyncSequenceService.countSequence() {
            values.append(value)
        }

        // THEN: We should receive the expected sequence of values
        #expect(values == [1, 2, 3, 4, 5])
    }

    @Test func eventStream() async {
        // GIVEN: An AsyncSequenceService that produces a stream of events
        let asyncSequenceService = service // SUT clearly identified
        var events: [String] = []

        // WHEN: We iterate through the event stream
        for await event in asyncSequenceService.eventStream() {
            events.append(event)
        }

        // THEN: We should receive all expected events in the correct order
        #expect(events == ["start", "processing", "complete"])
    }

    @Test func erroringSequence() async {
        // GIVEN: An AsyncSequenceService that produces a sequence that ends with an error
        let asyncSequenceService = service // SUT clearly identified
        var values: [Int] = []
        var caughtError: NSError?

        // WHEN: We iterate through the sequence and handle the error
        do {
            for try await value in asyncSequenceService.erroringSequence() {
                values.append(value)
            }
        } catch {
            caughtError = error as NSError
        }

        // THEN: We should receive the expected values and error
        #expect(values == [1, 2, 3])
        #expect(caughtError != nil)
        #expect(caughtError?.code == 400)
    }

    // Test partial consumption with early exit
    @Test func partialConsumption() async {
        // GIVEN: An AsyncSequenceService that produces a sequence of integers
        let asyncSequenceService = service // SUT clearly identified
        var count = 0

        // WHEN: We consume only the first 3 values
        for await _ in asyncSequenceService.countSequence() {
            count += 1
            if count == 3 {
                break
            }
        }

        // THEN: We should have consumed exactly 3 values
        #expect(count == 3, "Should have consumed exactly 3 values")
    }
}

// ===========================================================================================
//  ADVANCED EXAMPLE: CUSTOM ASYNCSEQUENCE
// ===========================================================================================

// A custom implementation of AsyncSequence for testing
struct CountdownSequence: AsyncSequence {
    typealias Element = Int

    let start: Int
    let delay: Duration

    init(from start: Int, delay: Duration = .milliseconds(50)) {
        self.start = start
        self.delay = delay
    }

    func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(start: start, delay: delay)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        let delay: Duration
        var current: Int

        init(start: Int, delay: Duration) {
            self.current = start
            self.delay = delay
        }

        mutating func next() async -> Int? {
            // Return nil when we reach zero
            if current <= 0 {
                return nil
            }

            // Introduce delay between values
            try? await Task.sleep(for: delay)

            let value = current
            current -= 1
            return value
        }
    }
}

// -----------------------------------------------------------------------------------------
// XCTEST APPROACH
// -----------------------------------------------------------------------------------------

class CustomAsyncSequenceXCTests: XCTestCase {
    func testCountdownSequence() async {
        // GIVEN: A custom countdown sequence starting from 5
        let countdownSequence = CountdownSequence(from: 5) // SUT clearly identified
        var values: [Int] = []

        // WHEN: We collect all values from the sequence
        for await value in countdownSequence {
            values.append(value)
        }

        // THEN: We should receive the expected countdown values
        XCTAssertEqual(values, [5, 4, 3, 2, 1])
    }

    func testEarlyTermination() async {
        // GIVEN: A custom countdown sequence starting from 10
        let countdownSequence = CountdownSequence(from: 10) // SUT clearly identified
        var values: [Int] = []
        var count = 0

        // WHEN: We break out of the iteration after 3 values
        for await value in countdownSequence {
            values.append(value)
            count += 1
            if count >= 3 {
                break
            }
        }

        // THEN: We should have collected only the first 3 values
        XCTAssertEqual(values, [10, 9, 8])
    }

    func testCancellation() async {
        // GIVEN: A custom countdown sequence with a long delay
        let expectation = self.expectation(description: "Sequence cancelled")
        let countdownSequence = CountdownSequence(from: 100, delay: .seconds(1)) // SUT clearly identified

        // WHEN: We start a task and then cancel it
        let task = Task {
            var count = 0
            for await _ in countdownSequence {
                count += 1
                if count >= 3 {
                    break
                }
            }
            expectation.fulfill()
        }

        // Cancel the task after a short wait
        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()

        // THEN: The task should be cancelled successfully
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}

// -----------------------------------------------------------------------------------------
// SWIFT TESTING APPROACH
// -----------------------------------------------------------------------------------------

struct CustomAsyncSequenceTests {
    @Test func countdownSequence() async {
        // GIVEN: A custom countdown sequence starting from 5
        let countdownSequence = CountdownSequence(from: 5) // SUT clearly identified
        var values: [Int] = []

        // WHEN: We collect all values from the sequence
        for await value in countdownSequence {
            values.append(value)
        }

        // THEN: We should receive the expected countdown values
        #expect(values == [5, 4, 3, 2, 1])
    }

    @Test func earlyTermination() async {
        // GIVEN: A custom countdown sequence starting from 10
        let countdownSequence = CountdownSequence(from: 10) // SUT clearly identified
        var values: [Int] = []
        var count = 0

        // WHEN: We break out of the iteration after 3 values
        for await value in countdownSequence {
            values.append(value)
            count += 1
            if count >= 3 {
                break
            }
        }

        // THEN: We should have collected only the first 3 values
        #expect(values == [10, 9, 8])
        #expect(count == 3)
    }

    @Test(.disabled()) func cancellation() async {
        // GIVEN: A custom countdown sequence with a long delay
        let countdownSequence = CountdownSequence(from: 100, delay: .seconds(1)) // SUT clearly identified

        // WHEN: We create a task, then cancel it before it completes
        let task = Task {
            var count = 0
            for await _ in countdownSequence {
                count += 1
            }
            return count
        }

        // Short wait then cancel
        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()

        // THEN: The task should be cancelled before completing the sequence
        let count = await task.value
        #expect(count < 100)
    }
}

// ===========================================================================================
//  STRUCTURED TESTING APPROACH: GIVEN-WHEN-THEN & SUT
// ===========================================================================================

// Define a simple publisher that we can test
class WeatherUpdatePublisher {
    // This simulates a publisher that emits weather updates
    func weatherUpdates() -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                // Simulating weather updates coming in over time
                try? await Task.sleep(for: .milliseconds(50))
                continuation.yield("Sunny")
                try? await Task.sleep(for: .milliseconds(50))
                continuation.yield("Cloudy")
                try? await Task.sleep(for: .milliseconds(50))
                continuation.yield("Rainy")
                continuation.finish()
            }
        }
    }

    // This publishes temperature updates with potential errors
    func temperatureUpdates() -> AsyncThrowingStream<Int, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                continuation.yield(72)
                try? await Task.sleep(for: .milliseconds(50))
                continuation.yield(68)

                // Simulate a sensor error
                continuation.finish(throwing: NSError(
                    domain: "WeatherSensor",
                    code: 503,
                    userInfo: [NSLocalizedDescriptionKey: "Temperature sensor malfunction"]
                ))
            }
        }
    }
}

// -----------------------------------------------------------------------------------------
// XCTEST APPROACH WITH GIVEN-WHEN-THEN
// -----------------------------------------------------------------------------------------

class StructuredWeatherUpdateXCTests: XCTestCase {
    func testWeatherUpdatesSequence() async {
        // GIVEN: A publisher that provides weather updates
        let weatherPublisher = WeatherUpdatePublisher() // SUT clearly identified
        var receivedUpdates: [String] = []

        // WHEN: We subscribe to the weather updates
        for await update in weatherPublisher.weatherUpdates() {
            receivedUpdates.append(update)
        }

        // THEN: We should receive the expected sequence of updates
        XCTAssertEqual(receivedUpdates.count, 3, "Should receive exactly 3 weather updates")
        XCTAssertEqual(receivedUpdates, ["Sunny", "Cloudy", "Rainy"], "Weather updates should arrive in correct order")
    }

    func testTemperatureUpdatesWithError() async {
        // GIVEN: A publisher that provides temperature updates with potential errors
        let weatherPublisher = WeatherUpdatePublisher() // SUT clearly identified
        var receivedTemperatures: [Int] = []
        var receivedError: NSError?

        // WHEN: We subscribe to the temperature updates
        do {
            for try await temperature in weatherPublisher.temperatureUpdates() {
                receivedTemperatures.append(temperature)
            }
        } catch {
            receivedError = error as NSError
        }

        // THEN: We should receive some updates and then an error
        XCTAssertEqual(receivedTemperatures, [72, 68], "Should receive exactly 2 temperature readings")
        XCTAssertNotNil(receivedError, "Should receive an error")
        XCTAssertEqual(receivedError?.domain, "WeatherSensor", "Error should be from the correct domain")
        XCTAssertEqual(receivedError?.code, 503, "Error should have the correct code")
    }
}

// -----------------------------------------------------------------------------------------
// SWIFT TESTING APPROACH WITH GIVEN-WHEN-THEN
// -----------------------------------------------------------------------------------------

struct StructuredWeatherUpdateTests {
    @Test func weatherUpdatesSequence() async {
        // GIVEN: A publisher that provides weather updates
        let weatherPublisher = WeatherUpdatePublisher() // SUT clearly identified
        var receivedUpdates: [String] = []

        // WHEN: We subscribe to the weather updates
        for await update in weatherPublisher.weatherUpdates() {
            receivedUpdates.append(update)
        }

        // THEN: We should receive the expected sequence of updates
        #expect(receivedUpdates.count == 3, "Should receive exactly 3 weather updates")
        #expect(receivedUpdates == ["Sunny", "Cloudy", "Rainy"], "Weather updates should arrive in correct order")
    }

    @Test func temperatureUpdatesWithError() async {
        // GIVEN: A publisher that provides temperature updates with potential errors
        let weatherPublisher = WeatherUpdatePublisher() // SUT clearly identified
        var receivedTemperatures: [Int] = []
        var receivedError: NSError?

        // WHEN: We subscribe to the temperature updates
        do {
            for try await temperature in weatherPublisher.temperatureUpdates() {
                receivedTemperatures.append(temperature)
            }
        } catch {
            receivedError = error as NSError
        }

        // THEN: We should receive some updates and then an error
        #expect(receivedTemperatures == [72, 68], "Should receive exactly 2 temperature readings")
        #expect(receivedError != nil, "Should receive an error")
        #expect(receivedError?.domain == "WeatherSensor", "Error should be from the correct domain")
        #expect(receivedError?.code == 503, "Error should have the correct code")
    }
    /*
    // Testing with explicit confirmation pattern for event-based testing
    @Test func weatherUpdatesWithConfirmation() async {
        // GIVEN: A publisher and a subscriber
        let weatherPublisher = WeatherUpdatePublisher() // SUT clearly identified

        // WHEN/THEN: We subscribe and confirm all expected events occur
        await confirmation(expectedCount: 3) { weatherUpdate in
            // Set up the subscriber with confirmation as the handler
            Task {
                for await update in weatherPublisher.weatherUpdates() {
                    // Confirm each weather update as it arrives
                    weatherUpdate()
                }
            }
        }
    }
     */
}

// ===========================================================================================
//  BEST PRACTICES FOR ASYNCSEQUENCE TESTING WITH GIVEN-WHEN-THEN
// ===========================================================================================

/*
 STRUCTURED ASYNCSEQUENCE TESTING BEST PRACTICES:

 1. CLEAR STRUCTURE
    - Always identify the System Under Test (SUT)
    - Use Given-When-Then comments to structure the test
    - Keep setup, action, and verification visually separated

 2. GIVEN - SETUP PHASE
    - Initialize the publisher/AsyncSequence
    - Prepare any test data or state needed
    - Setup capture mechanisms for outputs

 3. WHEN - ACTION PHASE
    - Subscribe to the AsyncSequence
    - Trigger the events being tested
    - Capture outputs from the sequence

 4. THEN - VERIFICATION PHASE
    - Verify the correct number of events were received
    - Check the values are correct and in the right order
    - Validate any error handling behavior

 5. TEST BOUNDARIES
    - Test normal operation
    - Test error conditions
    - Test early termination and cancellation
 */

// ===========================================================================================
//  TESTING COMBINE PUBLISHERS WITH SINK
// ===========================================================================================

// Define a publisher-based data source that we can test
class StockPricePublisher {
    // This returns a Combine publisher that emits stock price updates
    func priceUpdates(for symbol: String) -> AnyPublisher<Double, Error> {
        return Future<Double, Error> { promise in
            // Simulate fetching price data
            Task {
                try? await Task.sleep(for: .milliseconds(100))

                // Simulate success or error based on symbol
                if symbol == "ERROR" {
                    promise(.failure(NSError(
                        domain: "StockAPI",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Stock symbol not found"]
                    )))
                } else {
                    // Return a simulated price
                    let price = symbol == "AAPL" ? 190.50 : 150.25
                    promise(.success(price))
                }
            }
        }
        .delay(for: .milliseconds(50), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }

    // This returns a publisher that emits a stream of price updates
    func priceStream(for symbol: String) -> AnyPublisher<Double, Never> {
        let prices: [Double] = symbol == "AAPL" ? [180.5, 182.3, 185.7] : [90.2, 88.5, 92.1]

        return Publishers.Sequence(sequence: prices)
            .delay(for: .milliseconds(50), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

// -----------------------------------------------------------------------------------------
// XCTEST APPROACH WITH SINK OPERATOR
// -----------------------------------------------------------------------------------------

class StockPublisherXCTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testStockPricePublisher() {
        // GIVEN: A publisher that provides stock price data
        let stockPublisher = StockPricePublisher() // SUT clearly identified
        let expectation = self.expectation(description: "Price received")
        var receivedPrice: Double?
        var receivedError: Error?

        // WHEN: We subscribe to the price updates using sink
        stockPublisher.priceUpdates(for: "AAPL")
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        receivedError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { price in
                    receivedPrice = price
                }
            )
            .store(in: &cancellables)

        // Wait for publisher to complete
        wait(for: [expectation], timeout: 1.0)

        // THEN: We should receive the expected price
        XCTAssertNil(receivedError, "Should not receive an error")
        XCTAssertEqual(receivedPrice, 190.50, "Should receive correct AAPL price")
    }

    func test_StockPrice_Stream() {
        let stockPublisher = StockPricePublisher()
        let expectation = self.expectation(description: "All prices received")
        var receivedPrices: [Double] = []

        stockPublisher.priceStream(for: "AAPL")
            .sink(
                receiveCompletion: { _ in
                    expectation.fulfill()
                },
                receiveValue: { price in
                    receivedPrices.append(price)
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedPrices, [180.5, 182.3, 185.7])
    }

    func testStockPriceStream() {
        // GIVEN: A publisher that provides a stream of stock prices
        let stockPublisher = StockPricePublisher() // SUT clearly identified
        let expectation = self.expectation(description: "All prices received")
        var receivedPrices: [Double] = []

        // WHEN: We subscribe to the price stream using sink
        stockPublisher.priceStream(for: "AAPL")
            .sink(
                receiveCompletion: { _ in
                    expectation.fulfill()
                },
                receiveValue: { price in
                    receivedPrices.append(price)
                }
            )
            .store(in: &cancellables)

        // Wait for publisher to complete
        wait(for: [expectation], timeout: 1.0)

        // THEN: We should receive all expected prices in order
        XCTAssertEqual(receivedPrices, [180.5, 182.3, 185.7], "Should receive all price updates in correct order")
    }

    func testErrorHandling() {
        // GIVEN: A publisher that will fail for certain symbols
        let stockPublisher = StockPricePublisher() // SUT clearly identified
        let expectation = self.expectation(description: "Error received")
        var receivedError: NSError?

        // WHEN: We subscribe to an invalid symbol using sink
        stockPublisher.priceUpdates(for: "ERROR")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error as NSError
                    }
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        // Wait for publisher to complete
        wait(for: [expectation], timeout: 1.0)

        // THEN: We should receive the expected error
        XCTAssertNotNil(receivedError, "Should receive an error")
        XCTAssertEqual(receivedError?.domain, "StockAPI", "Error should be from the correct domain")
        XCTAssertEqual(receivedError?.code, 404, "Error should have the correct code")
    }
}

// -----------------------------------------------------------------------------------------
// SWIFT TESTING APPROACH WITH SINK OPERATOR
// -----------------------------------------------------------------------------------------

struct StockPublisherTests {
    @Test func stockPricePublisher() async {
        // GIVEN: A publisher that provides stock price data
        let stockPublisher = StockPricePublisher() // SUT clearly identified
        var receivedPrice: Double?
        var receivedError: Error?

        // Create a Task to await completion
        await withCheckedContinuation { continuation in
            // WHEN: We subscribe to the price updates using sink
            stockPublisher.priceUpdates(for: "AAPL")
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            receivedError = error
                        }
                        continuation.resume()
                    },
                    receiveValue: { price in
                        receivedPrice = price
                    }
                )
                .store(in: &SetupMethods.cancellables)
        }

        // THEN: We should receive the expected price
        #expect(receivedError == nil, "Should not receive an error")
        #expect(receivedPrice == 190.50, "Should receive correct AAPL price")
    }

    @Test(.disabled()) func stockPriceStream() async {
        // GIVEN: A publisher that provides a stream of stock prices
        let stockPublisher = StockPricePublisher() // SUT clearly identified
        var receivedPrices: [Double] = []

        // Create a Task to await completion
        await withCheckedContinuation { continuation in
            // WHEN: We subscribe to the price stream using sink
            stockPublisher.priceStream(for: "AAPL")
                .sink(
                    receiveCompletion: { _ in
                        continuation.resume()
                    },
                    receiveValue: { price in
                        receivedPrices.append(price)
                    }
                )
                .store(in: &SetupMethods.cancellables)
        }

        // THEN: We should receive all expected prices in order
        #expect(receivedPrices == [180.5, 182.3, 185.7], "Should receive all price updates in correct order")
    }

    @Test func errorHandling() async {
        // GIVEN: A publisher that will fail for certain symbols
        let stockPublisher = StockPricePublisher() // SUT clearly identified
        var receivedError: NSError?

        // Create a Task to await completion
        await withCheckedContinuation { continuation in
            // WHEN: We subscribe to an invalid symbol using sink
            stockPublisher.priceUpdates(for: "ERROR")
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            receivedError = error as NSError
                        }
                        continuation.resume()
                    },
                    receiveValue: { _ in }
                )
                .store(in: &SetupMethods.cancellables)
        }

        // THEN: We should receive the expected error
        #expect(receivedError != nil, "Should receive an error")
        #expect(receivedError?.domain == "StockAPI", "Error should be from the correct domain")
        #expect(receivedError?.code == 404, "Error should have the correct code")
    }

    /*
    // Using confirmation for event-based testing
    @Test func stockPriceWithConfirmation() async {
        // GIVEN: A publisher that provides stock prices
        let stockPublisher = StockPricePublisher() // SUT clearly identified
        var receivedPrice: Double?

        // WHEN/THEN: We subscribe and confirm when values are received
        await confirmation { priceReceived in
            stockPublisher.priceUpdates(for: "AAPL")
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { price in
                        receivedPrice = price
                        priceReceived() // Confirm the event occurred
                    }
                )
                .store(in: &SetupMethods.cancellables)
        }

        // Additional verification
        #expect(receivedPrice == 190.50, "Should receive correct AAPL price")
    }
     */
}

// Setup methods for Swift Testing
enum SetupMethods {
    static var cancellables = Set<AnyCancellable>()
}

// ===========================================================================================
//  BEST PRACTICES FOR TESTING COMBINE PUBLISHERS
// ===========================================================================================

/*
 COMBINE PUBLISHER TESTING BEST PRACTICES:

 1. FOLLOW GIVEN-WHEN-THEN STRUCTURE
    - GIVEN: Setup the publisher and necessary test state
    - WHEN: Subscribe using sink and store the cancellable
    - THEN: Verify the expected values and completion

 2. MANAGE CANCELLABLES
    - Always store cancellables in a Set<AnyCancellable>
    - Clear cancellables between tests to prevent memory leaks
    - Consider using a shared cancellable storage for reuse

 3. HANDLE ASYNCHRONOUS COMPLETION
    - Use XCTestExpectation in XCTest to await publisher completion
    - Use withCheckedContinuation in Swift Testing for awaiting completion
    - Use the confirmation pattern for event-based testing in Swift Testing

 4. TEST DIFFERENT PUBLISHER BEHAVIORS
    - Test successful value emission
    - Test error handling
    - Test multiple value streams
    - Test cancellation behavior

 5. PROVIDE EXPLICIT ASSERTIONS
    - Include descriptive messages in assertions/expectations
    - Verify both the values and their order
    - For errors, check both the error type and properties
 */

// ===========================================================================================
//  README: ASYNCSEQUENCE TESTING WITH SUT AND GIVEN-WHEN-THEN APPROACH
// ===========================================================================================

/*
 ASYNCSEQUENCE TESTING BEST PRACTICES WITH SUT AND GIVEN-WHEN-THEN:

 1. SYSTEM UNDER TEST (SUT) PATTERN
    - Clearly identify what component is being tested (the System Under Test)
    - Make the SUT explicit in your test method to clarify what's being tested
    - Focus each test on a single responsibility of the SUT
    - Use descriptive variable names that indicate the SUT role

 2. GIVEN-WHEN-THEN STRUCTURE
    - GIVEN: Set up the test environment and preconditions
      * Initialize the SUT with known state
      * Prepare test data and expected results
      * Set up any mocks or dependencies needed

    - WHEN: Perform the action being tested
      * Call methods on the SUT
      * Subscribe to AsyncSequences or publishers
      * Trigger the behavior under test

    - THEN: Verify the expected outcomes
      * Check the values received from AsyncSequences
      * Verify the order and timing of events
      * Validate proper error handling

 3. TEST ORGANIZATION
    - Use descriptive test method names that clearly state what's being tested
    - Keep tests focused on a single behavior or scenario
    - Structure test code to mirror the GIVEN-WHEN-THEN flow
    - Add comments to clearly separate the three phases

 4. VERIFICATION STRATEGIES
    - For AsyncSequence: Collect and verify values in the correct order
    - For Publishers: Use sink with appropriate completion handling
    - For errors: Test both the happy path and error conditions
    - For completion: Verify sequences terminate as expected
 */

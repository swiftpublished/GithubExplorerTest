import XCTest
@testable import GithubExplorerTest

@MainActor
class GithubHomeViewModelXCTest: XCTestCase {

    // Using the same mock repositories data as in the DSL tests for consistency.
    let mockRepositories = [
        Repository.testData(
            id: 1,
            name: "SwiftUI",
            forksCount: 2500,
            stargazersCount: 15000,
            description: "UI Framework"
        ),
        Repository.testData(
            id: 2,
            name: "Combine",
            forksCount: 1200,
            stargazersCount: 800,
            description: "Reactive Framework"
        )
    ]

    var viewModel: GithubHomeViewModel!

    override func setUp() {
        super.setUp()
        // Initialize with a mock service returning the mock repositories.
        viewModel = GithubHomeViewModel(apiService: MockAPIServiceForHomeViewModel(repositories: mockRepositories))
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Search Tests

    func testSearchRepositoriesFiltersByNameAndDescription() {
        // Define test cases as tuples: (query, expectedCount)
        let testCases: [(query: String, expectedCount: Int)] = [
            ("test", 0),
            ("swiftui", 1),
            ("framework", 2),
            ("xyze", 0),
            ("", 0)
        ]

        let testRepositories = [
            Repository.testData(
                id: 1,
                name: "SwiftUI",
                forksCount: 2500,
                stargazersCount: 15000,
                description: "UI Framework"
            ),
            Repository.testData(
                id: 2,
                name: "Combine",
                forksCount: 1200,
                stargazersCount: 800,
                description: "Reactive Framework"
            )
        ]

        for testCase in testCases {
            let expectation = self.expectation(description: "Search result for query: \"\(testCase.query)\"")

            // Use the utility function to filter repositories
            let searchResults = RepositorySearchUtils.filterRepositories(testRepositories, query: testCase.query)
            let apiService = MockAPIServiceForHomeViewModel(searchResults: searchResults)

            let vm = GithubHomeViewModel(apiService: apiService)
            vm.searchText = testCase.query

            Task {
                await vm.searchRepositories()
                XCTAssertEqual(vm.searchResults.count, testCase.expectedCount,
                               "Unexpected search result count for query: \"\(testCase.query)\"")
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1)
        }
    }

    // MARK: - Fetch Repositories Tests

    func testFetchRepositories_success() {
        let expectation = self.expectation(description: "Fetch Repositories")

        Task {
            await viewModel.fetchRepositories()
            XCTAssertEqual(viewModel.repositories.count, mockRepositories.count, "Repository count mismatch")
            XCTAssertEqual(viewModel.displayState, .success, "Display state should be success")
            XCTAssertNil(viewModel.errorMessage, "Error message should be nil on success")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testFetchRepositories_failure() {
        // Use a failing API service.
        viewModel = GithubHomeViewModel(apiService: FailingAPIServiceForHomeViewModel())
        let expectation = self.expectation(description: "Fetch Failure")

        Task {
            await viewModel.fetchRepositories()
            if case .error(let message) = viewModel.displayState {
                XCTAssertFalse(message.isEmpty, "Error message should not be empty")
            } else {
                XCTFail("Expected display state to be error")
            }
            XCTAssertTrue(viewModel.repositories.isEmpty, "Repositories should be empty on failure")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Search Tests (Empty Query)

    func testSearchRepositories_emptyQuery() {
        viewModel = GithubHomeViewModel(apiService: MockAPIServiceForHomeViewModel())
        viewModel.searchText = "   " // Only whitespace

        let expectation = self.expectation(description: "Empty Search")
        Task {
            await viewModel.searchRepositories()
            XCTAssertTrue(viewModel.searchResults.isEmpty, "Search results should be empty for an empty query")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Sorting Tests

    func testSortRepositoriesByStars() {
        // Set repositories manually.
        viewModel.repositories = [
            Repository.testData(id: 1, stargazersCount: 100),
            Repository.testData(id: 2, stargazersCount: 500)
        ]
        viewModel.sortRepositoriesByStars(ascending: true)
        XCTAssertEqual(viewModel.repositories.first?.id, 1, "Ascending sort: first repo should have id 1")

        viewModel.sortRepositoriesByStars(ascending: false)
        XCTAssertEqual(viewModel.repositories.first?.id, 2, "Descending sort: first repo should have id 2")
    }

    func testSortRepositoriesByForks() {
        viewModel.repositories = [
            Repository.testData(id: 1, forksCount: 300),
            Repository.testData(id: 2, forksCount: 100)
        ]
        viewModel.sortRepositoriesByForks(ascending: true)
        XCTAssertEqual(viewModel.repositories.first?.id, 2, "Ascending sort: first repo should have id 2")

        viewModel.sortRepositoriesByForks(ascending: false)
        XCTAssertEqual(viewModel.repositories.first?.id, 1, "Descending sort: first repo should have id 1")
    }

    // MARK: - Model Tests

    func testRepositoryStarRating() {
        // Given
        let repo = Repository.testData(stargazersCount: 12500)
        // Then
        XCTAssertEqual(repo.starRating, "⭐⭐⭐⭐⭐", "Star rating should be 5 stars")
    }

    func testPopularRepositoryFlag() {
        // Given
        let popularRepo = Repository.testData(stargazersCount: 1500)
        let unpopularRepo = Repository.testData(stargazersCount: 999)
        // Then
        XCTAssertTrue(popularRepo.isPopular, "Repo should be popular")
        XCTAssertFalse(unpopularRepo.isPopular, "Repo should not be popular")
    }

    func testFormattedForks() {
        // Given
        let repo = Repository.testData(forksCount: 1234)
        // Then
        XCTAssertEqual(repo.formattedForks, "1234 forks", "Fork count formatting is incorrect")
    }
}

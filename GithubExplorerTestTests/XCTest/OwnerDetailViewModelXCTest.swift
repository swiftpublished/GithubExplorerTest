import XCTest
@testable import GithubExplorerTest
// MARK: - OwnerDetailViewModel XCTest Tests

@MainActor
class OwnerDetailViewModelXCTest: XCTestCase {
    var viewModel: OwnerDetailViewModel!
    var owner: Owner!

    override func setUp() {
        super.setUp()
        owner = Owner.testOwner(login: "testuser")
        viewModel = OwnerDetailViewModel(owner: owner, apiService: MockAPIServiceForOwnerDetail(repositories: [
            Repository.testData(id: 1, stargazersCount: 100),
            Repository.testData(id: 2, stargazersCount: 200)
        ]))
    }

    override func tearDown() {
        viewModel = nil
        owner = nil
        super.tearDown()
    }

    func testFetchOwnerRepositoriesSuccess() {
        let expectation = self.expectation(description: "Fetch Owner Repositories")
        Task {
            await viewModel.fetchOwnerRepositories()
            XCTAssertEqual(viewModel.repositories.count, 2, "Expected two repositories")
            XCTAssertFalse(viewModel.isLoading, "isLoading should be false after fetch")
            XCTAssertNil(viewModel.errorMessage, "No error message expected on success")
            XCTAssertEqual(viewModel.totalStars, 300, "Total stars should be 300")
            XCTAssertEqual(viewModel.repositoryCount, 2, "Repository count should be 2")
            XCTAssertEqual(viewModel.ownerName, "testuser", "Owner name should be testuser")
            // Verify sorted order (highest star first)
            XCTAssertEqual(viewModel.sortedRepositories.first?.stargazersCount, 200, "First sorted repo should have 200 stars")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testFetchOwnerRepositoriesFailure() {
        viewModel = OwnerDetailViewModel(owner: owner, apiService: FailingAPIServiceForOwnerDetail())
        let expectation = self.expectation(description: "Fetch Owner Repositories Failure")
        Task {
            await viewModel.fetchOwnerRepositories()
            XCTAssertTrue(viewModel.repositories.isEmpty, "Expected no repositories on failure")
            XCTAssertFalse(viewModel.isLoading, "isLoading should be false after failure")
            XCTAssertNotNil(viewModel.errorMessage, "Expected an error message on failure")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
}

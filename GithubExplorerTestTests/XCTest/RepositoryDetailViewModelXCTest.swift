import XCTest
@testable import GithubExplorerTest

@MainActor
class RepositoryDetailViewModelXCTest: XCTestCase {

    // Using the same initial repository data as in the DSL tests for consistency.
    let initialRepository = Repository.testData(
        id: 1,
        name: "TestRepo",
        forksCount: 100,
        stargazersCount: 500,
        description: "Initial Description",
        owner: Owner.testOwner(login: "testuser", avatarUrl: "https://example.com/avatar.png")
    )

    // MARK: - Refresh Tests

    func testRefreshRepositoryDetails_success() async {
        // Given: A new repository returned by the API service.
        let updatedRepository = Repository.testData(
            id: 1,
            name: "UpdatedRepo",
            forksCount: 150,
            stargazersCount: 600,
            description: "Updated Description",
            owner: Owner.testOwner(login: "updatedUser", avatarUrl: "https://example.com/updated_avatar.png")
        )

        struct MockAPIServiceForRepositoryDetail: APIServiceProtocol {
            let updatedRepository: Repository
            func fetchRepositories(category: RepoCategory) async throws -> [Repository] { [] }
            func searchRepositories(query: String) async throws -> [Repository] { [] }
            func fetchRepositoryDetails(id: Int) async throws -> Repository {
                return updatedRepository
            }
        }

        let mockService = MockAPIServiceForRepositoryDetail(updatedRepository: updatedRepository)
        let vm = RepositoryDetailViewModel(repository: initialRepository, apiService: mockService)

        // When: Refreshing the repository details.
        await vm.refreshRepositoryDetails()

        // Then: Verify that repository details have been updated.
        XCTAssertEqual(vm.repository.name, "UpdatedRepo", "Repository name should be updated")
        XCTAssertEqual(vm.repository.forksCount, 150, "Repository forks should be updated")
        XCTAssertEqual(vm.repository.stargazersCount, 600, "Repository stars should be updated")
        XCTAssertNil(vm.errorMessage, "Error message should be nil on success")
        XCTAssertFalse(vm.isLoading, "Loading should be false after refresh")
    }

    func testRefreshRepositoryDetails_failure() async {
        // Given: A failing API service that always throws an error.
        struct FailingAPIServiceForRepositoryDetail: APIServiceProtocol {
            func fetchRepositories(category: RepoCategory) async throws -> [Repository] { [] }
            func searchRepositories(query: String) async throws -> [Repository] { [] }
            func fetchRepositoryDetails(id: Int) async throws -> Repository {
                throw NSError(domain: "TestError", code: 500,
                              userInfo: [NSLocalizedDescriptionKey: "Detail fetch error"])
            }
        }

        let failingService = FailingAPIServiceForRepositoryDetail()
        let vm = RepositoryDetailViewModel(repository: initialRepository, apiService: failingService)

        // When: Refreshing the repository details.
        await vm.refreshRepositoryDetails()

        // Then: Verify that an error is reported and loading is finished.
        XCTAssertNotNil(vm.errorMessage, "Error message should be set on failure")
        XCTAssertTrue(vm.errorMessage?.contains("Detail fetch error") ?? false, "Error message should indicate detail fetch error")
        XCTAssertFalse(vm.isLoading, "Loading should be false after refresh failure")
    }

    // MARK: - Computed Properties Tests

    func testComputedProperties() {
        // Given: A repository with known values.
        let repo = Repository.testData(
            id: 2,
            name: "SampleRepo",
            forksCount: 200,
            stargazersCount: 800,
            description: "A sample repository",
            owner: Owner.testOwner(login: "sampleOwner", avatarUrl: "https://example.com/sample.png")
        )
        let vm = RepositoryDetailViewModel(repository: repo)

        // Then: Validate computed properties.
        XCTAssertEqual(vm.ownerName, "sampleOwner", "Owner name should be 'sampleOwner'")
        XCTAssertEqual(vm.repositoryName, "SampleRepo", "Repository name should be 'SampleRepo'")
        XCTAssertEqual(vm.description, "A sample repository", "Description should match")
        XCTAssertEqual(vm.starCount, "800", "Star count should be '800'")
        XCTAssertEqual(vm.forkCount, "200", "Fork count should be '200'")
        XCTAssertEqual(vm.isPopular, (repo.stargazersCount ?? 0) >= 1000, "isPopular should be computed correctly")
        XCTAssertEqual(vm.ownerAvatarUrl, "https://example.com/sample.png", "Owner avatar URL should match")

        let expectedUrl = URL(string: "https://github.com/sampleOwner/SampleRepo")!
        XCTAssertEqual(vm.repositoryUrl, expectedUrl, "Repository URL should be constructed correctly")
    }
}

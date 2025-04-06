import Testing
@testable import GithubExplorerTest
import Foundation

@MainActor
@Suite
struct RepositoryDetailViewModelTests {

    // MARK: - Properties

    let initialRepository = Repository.testData(
        id: 1,
        name: "TestRepo",
        forksCount: 100,
        stargazersCount: 500,
        description: "Initial Description",
        owner: Owner.testOwner(login: "testuser", avatarUrl: "https://example.com/avatar.png")
    )

    // MARK: - Refresh Tests

    @Test(.tags(.refresh))
    func refreshRepositoryDetails_success() async {
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
        #expect(vm.repository.name == "UpdatedRepo", "Repository name should be updated")
        #expect(vm.repository.forksCount == 150, "Repository forks should be updated")
        #expect(vm.repository.stargazersCount == 600, "Repository stars should be updated")
        #expect(vm.errorMessage == nil, "Error message should be nil on success")
        #expect(vm.isLoading == false, "Loading should be false after refresh")
    }

    @Test(.tags(.refresh))
    func refreshRepositoryDetails_failure() async {
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
        #expect(vm.errorMessage?.contains("Detail fetch error") == true, "Error message should indicate detail fetch error")
        #expect(vm.isLoading == false, "Loading should be false after refresh failure")
    }

    // MARK: - Computed Properties Tests

    @Test(.tags(.computed))
    func computedProperties() {
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
        #expect(vm.ownerName == "sampleOwner", "Owner name should be 'sampleOwner'")
        #expect(vm.repositoryName == "SampleRepo", "Repository name should be 'SampleRepo'")
        #expect(vm.description == "A sample repository", "Description should match")
        #expect(vm.starCount == "800", "Star count should be '800'")
        #expect(vm.forkCount == "200", "Fork count should be '200'")
        #expect(vm.isPopular == ((repo.stargazersCount ?? 0) >= 1000), "isPopular should be computed correctly")
        #expect(vm.ownerAvatarUrl == "https://example.com/sample.png", "Owner avatar URL should match")

        let expectedUrl = URL(string: "https://github.com/sampleOwner/SampleRepo")!
        #expect(vm.repositoryUrl == expectedUrl, "Repository URL should be constructed correctly")
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var refresh: Self
    @Tag static var computed: Self
}

import Testing
@testable import GithubExplorerTest
import Foundation

@MainActor
@Suite
struct GitHubHomeViewModelTests {
    // MARK: - Properties
    private let mockRepositories = [
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

    // MARK: - Search Tests
    @Test(.tags(.search), arguments: [
        ("test", 0),
        ("swiftui", 1),
        ("framework", 2),
        ("xyze", 0),
        ("", 0)
    ])
    func searchRepositoriesFiltersByNameAndDescription(query: String, expectedCount: Int) async {
        // Given
        let searchResults = RepositorySearchUtils.filterRepositories(mockRepositories, query: query)
        let apiService = MockAPIServiceForHomeViewModel(searchResults: searchResults)
        let vm = GithubHomeViewModel(apiService: apiService)

        // When
        vm.searchText = query
        await vm.searchRepositories()

        // Then
        #expect(vm.searchResults.count == expectedCount, "Expected \(expectedCount) results for query '\(query)'")
    }

    // MARK: - Fetch Repositories Tests
    @Test(.tags(.network))
    func fetchRepositories_success() async {
        // Given
        let apiService = MockAPIServiceForHomeViewModel(repositories: mockRepositories)
        let vm = GithubHomeViewModel(apiService: apiService)

        // When
        await vm.fetchRepositories()

        // Then
        #expect(vm.displayState == .success, "Display state should be success")
        #expect(vm.repositories.count == mockRepositories.count, "Repository count mismatch")
        #expect(vm.errorMessage == nil, "Error message should be nil on success")
    }

    @Test(.tags(.network))
    func fetchRepositories_failure() async {
        // Given
        let apiService = FailingAPIServiceForHomeViewModel()
        let vm = GithubHomeViewModel(apiService: apiService)

        // When
        await vm.fetchRepositories()

        // Then
        if case .error(let message) = vm.displayState {
            #expect(!message.isEmpty, "Error message should not be empty")
        } else {
            Issue.record("Expected display state to be error")
        }
        #expect(vm.repositories.isEmpty, "Repositories should be empty on failure")
    }

    @Test(.tags(.search))
    func searchRepositories_emptyQuery() async {
        // Given
        let apiService = MockAPIServiceForHomeViewModel()
        let vm = GithubHomeViewModel(apiService: apiService)

        // When
        vm.searchText = "   "
        await vm.searchRepositories()

        // Then
        #expect(vm.searchResults.isEmpty, "Search results should be empty for empty query")
    }

    // MARK: - Sorting Tests
    @Test(.tags(.sorting))
    func sortRepositoriesByStars() async {
        // Given
        let vm = GithubHomeViewModel(apiService: MockAPIServiceForHomeViewModel(repositories: mockRepositories))
        await vm.fetchRepositories()

        // When - Sort ascending
        vm.sortRepositoriesByStars(ascending: true)

        // Then
        #expect(vm.repositories.first?.stargazersCount == 800, "First repo should have 800 stars")
        #expect(vm.repositories.last?.stargazersCount == 15000, "Last repo should have 15000 stars")

        // When - Sort descending
        vm.sortRepositoriesByStars(ascending: false)

        // Then
        #expect(vm.repositories.first?.stargazersCount == 15000, "First repo should have 15000 stars")
        #expect(vm.repositories.last?.stargazersCount == 800, "Last repo should have 800 stars")
    }

    @Test(.tags(.sorting))
    func sortRepositoriesByForks() async {
        // Given
        let vm = GithubHomeViewModel(apiService: MockAPIServiceForHomeViewModel(repositories: mockRepositories))
        await vm.fetchRepositories()

        // When - Sort ascending
        vm.sortRepositoriesByForks(ascending: true)

        // Then
        #expect(vm.repositories.first?.forksCount == 1200, "First repo should have 1200 forks")
        #expect(vm.repositories.last?.forksCount == 2500, "Last repo should have 2500 forks")

        // When - Sort descending
        vm.sortRepositoriesByForks(ascending: false)

        // Then
        #expect(vm.repositories.first?.forksCount == 2500, "First repo should have 2500 forks")
        #expect(vm.repositories.last?.forksCount == 1200, "Last repo should have 1200 forks")
    }

    // MARK: - Model Tests
    @Test(.tags(.model))
    func repositoryStarRating() {
        // Given
        let repo = Repository.testData(stargazersCount: 12500)

        // Then
        #expect(repo.starRating == "⭐⭐⭐⭐⭐", "Star rating should be 5 stars")
    }

    @Test(.tags(.model))
    func popularRepositoryFlag() {
        // Given
        let popularRepo = Repository.testData(stargazersCount: 1500)
        let unpopularRepo = Repository.testData(stargazersCount: 999)

        // Then
        #expect(popularRepo.isPopular, "Repo should be popular")
        #expect(!unpopularRepo.isPopular, "Repo should not be popular")
    }

    @Test(.tags(.model))
    func formattedForks() {
        // Given
        let repo = Repository.testData(forksCount: 1234)

        // Then
        #expect(repo.formattedForks == "1234 forks", "Fork count formatting is incorrect")
    }
}

// MARK: - Test Tags
extension Tag {
    @Tag static var search: Self
    @Tag static var sorting: Self
    @Tag static var model: Self
}

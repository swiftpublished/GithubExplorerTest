// MARK: - Mocks for GithubHomeViewModel Tests
import XCTest
@testable import GithubExplorerTest


struct MockAPIServiceForHomeViewModel: APIServiceProtocol {
    var repositories: [Repository]
    var searchResults: [Repository]

    init(repositories: [Repository] = [], searchResults: [Repository] = []) {
        self.repositories = repositories
        self.searchResults = searchResults
    }

    func fetchRepositories(category: RepoCategory) async throws -> [Repository] {
        return repositories
    }

    func searchRepositories(query: String) async throws -> [Repository] {
        return searchResults
    }

    func fetchRepositoryDetails(id: Int) async throws -> Repository {
        return Repository.testData(id: id)
    }
}

struct FailingAPIServiceForHomeViewModel: APIServiceProtocol {
    func fetchRepositories(category: RepoCategory) async throws -> [Repository] {
        throw NSError(domain: "TestError", code: 500,
                      userInfo: [NSLocalizedDescriptionKey: "Test error for fetchRepositories"])
    }

    func searchRepositories(query: String) async throws -> [Repository] {
        throw NSError(domain: "TestError", code: 500,
                      userInfo: [NSLocalizedDescriptionKey: "Test error for searchRepositories"])
    }

    func fetchRepositoryDetails(id: Int) async throws -> Repository {
        throw NSError(domain: "TestError", code: 500,
                      userInfo: [NSLocalizedDescriptionKey: "Test error for fetchRepositoryDetails"])
    }
}

// MARK: - Mocks for OwnerDetailViewModel Tests

struct MockAPIServiceForOwnerDetail: APIServiceProtocol {
    var repositories: [Repository]

    func fetchRepositories(category: RepoCategory) async throws -> [Repository] {
        return repositories
    }

    func searchRepositories(query: String) async throws -> [Repository] {
        return repositories
    }

    func fetchRepositoryDetails(id: Int) async throws -> Repository {
        fatalError("Not implemented for OwnerDetail tests")
    }
}

struct FailingAPIServiceForOwnerDetail: APIServiceProtocol {
    func fetchRepositories(category: RepoCategory) async throws -> [Repository] {
        throw NSError(domain: "TestError", code: 500,
                      userInfo: [NSLocalizedDescriptionKey: "Test error"])
    }

    func searchRepositories(query: String) async throws -> [Repository] {
        throw NSError(domain: "TestError", code: 500,
                      userInfo: [NSLocalizedDescriptionKey: "Test error"])
    }

    func fetchRepositoryDetails(id: Int) async throws -> Repository {
        fatalError("Not implemented for OwnerDetail tests")
    }
}

// MARK: - Test Helpers

extension Repository {
    static func testData(
        id: Int = 1,
        name: String = "TestRepo",
        forksCount: Int? = 0,
        stargazersCount: Int? = 0,
        description: String = "Test Description",
        owner: Owner? = Owner.testOwner()
    ) -> Repository {
        return Repository(
            id: id,
            name: name,
            owner: owner,
            forksCount: forksCount,
            stargazersCount: stargazersCount,
            description: description
        )
    }
}

extension Owner {
    static func testOwner(
        id: Int = 1,
        login: String = "testuser",
        avatarUrl: String = "https://example.com/avatar.png"
    ) -> Owner {
        return Owner(
            id: id,
            login: login,
            avatarUrl: avatarUrl
        )
    }
}

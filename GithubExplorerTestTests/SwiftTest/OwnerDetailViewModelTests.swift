import Testing
@testable import GithubExplorerTest
import Foundation

@MainActor
struct OwnerDetailViewModelTests {

    @Test func fetchOwnerRepositories_success() async {
        let owner = Owner.testOwner(login: "testuser")
        let mockRepositories = [
            Repository.testData(id: 1, stargazersCount: 100),
            Repository.testData(id: 2, stargazersCount: 200)
        ]
        let apiService = MockAPIServiceForOwnerDetail(repositories: mockRepositories)
        let vm = OwnerDetailViewModel(owner: owner, apiService: apiService)
        await vm.fetchOwnerRepositories()
        #expect(vm.repositories.count == 2, "Expected two repositories")
        #expect(vm.isLoading == false, "isLoading should be false after fetch")
        #expect(vm.errorMessage == nil, "No error message expected on success")
        #expect(vm.totalStars == 300, "Total stars should be 300")
        #expect(vm.repositoryCount == 2, "Repository count should be 2")
        #expect(vm.ownerName == "testuser", "Owner name should be testuser")
        #expect(vm.sortedRepositories.first?.stargazersCount == 200, "First sorted repository should have 200 stars")
    }

    @Test func fetchOwnerRepositories_failure() async {
        let owner = Owner.testOwner(login: "testuser")
        let apiService = FailingAPIServiceForOwnerDetail()
        let vm = OwnerDetailViewModel(owner: owner, apiService: apiService)
        await vm.fetchOwnerRepositories()
        #expect(vm.repositories.isEmpty, "Expected no repositories on failure")
        #expect(vm.isLoading == false, "isLoading should be false after failure")
        #expect(vm.errorMessage != nil, "Expected an error message on failure")
    }
}

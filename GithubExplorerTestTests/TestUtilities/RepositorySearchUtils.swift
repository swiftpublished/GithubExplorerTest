import Foundation
@testable import GithubExplorerTest

/// Utility functions for repository search testing
struct RepositorySearchUtils {

    /// Filters repositories based on a simple search query
    /// - Parameters:
    ///   - repositories: Repositories to filter
    ///   - query: Search query
    /// - Returns: Filtered repositories that match the query
    static func filterRepositories(_ repositories: [Repository], query: String) -> [Repository] {
        query.isEmpty ? [] : repositories.filter { repo in
            let searchableText = [
                repo.name?.lowercased(),
                repo.description?.lowercased()
            ].compactMap { $0 }.joined(separator: " ")
            return searchableText.contains(query.lowercased())
        }
    }
}

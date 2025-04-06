import Testing
import XCTest
@testable import GithubExplorerTest

// ===========================================================================================
//
//  SWIFT TESTING CUSTOM TRAITS: A PRACTICAL GUIDE
//  ---------------------------------------------
//
//  This guide demonstrates how to create and use Custom Traits in Swift Testing,
//  with practical examples that show when and why you'd want to use them.
//
// ===========================================================================================

/*
 WHAT ARE CUSTOM TRAITS?

 Custom traits are a powerful extension mechanism in Swift Testing that let you:

 1. MODIFY TEST BEHAVIOR: Set up test environments automatically before tests run
 2. CONTROL TEST EXECUTION: Skip tests conditionally when prerequisites aren't met
 3. CLEAN UP RESOURCES: Ensure proper teardown after tests complete
 4. REUSE COMPLEX SETUP: Package common test setup logic into reusable components

 The key to a custom trait is implementing the `prepare(for:)` method, which runs
 before a test executes, letting you configure the environment or skip the test
 if conditions aren't right.
 */

// ===========================================================================================
//  CUSTOM TRAIT ANATOMY
// ===========================================================================================

/*
 A complete custom trait typically includes:

 1. A struct conforming to the TestTrait protocol
 2. Configuration properties to control the trait's behavior
 3. A 'prepare(for:)' method that runs before the test
 4. Optional teardown code via test.addTeardownBlock
 5. An extension on Test to provide a clean API for using the trait
 */

// ===========================================================================================
//  EXAMPLE 1: USER AUTHENTICATION TRAIT
// ===========================================================================================

/// A trait that ensures a user is authenticated before running a test
struct AuthenticatedUserTrait: TestTrait {
    // MARK: - Configuration

    enum UserType {
        case admin
        case standard
        case guest

        var credentials: (username: String, password: String) {
            switch self {
            case .admin:
                return ("admin_user", "adminP@ss123")
            case .standard:
                return ("standard_user", "userP@ss123")
            case .guest:
                return ("guest_user", "guestP@ss123")
            }
        }
    }

    // MARK: - Properties

    let userType: UserType
    let comments: [Comment]

    var description: String {
        "Testing with authenticated \(userType) user"
    }

    // MARK: - Initialization

    init(as userType: UserType = .standard, _ comment: Comment? = nil) {
        print("DEBUG: Creating AuthenticatedUserTrait with userType: \(userType)")
        self.userType = userType
        self.comments = comment.map { [$0] } ?? []
    }

    // MARK: - TestTrait Implementation

    func prepare(for test: Test) async throws {
        print("DEBUG: AuthenticatedUserTrait.prepare() started for test: \(test.name)")
        let credentials = userType.credentials

        // Explicitly reset auth state first
        await AuthManager.shared.logout()

        // Simulate logging in the user for this test
        print("DEBUG: Logging in as \(userType) user")
        try await AuthService.shared.login(
            username: credentials.username,
            password: credentials.password
        )

        // Verify login worked correctly
        guard let currentUser = AuthManager.shared.currentUser() else {
            throw NSError(domain: "AuthError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Login failed - currentUser is nil after login"
            ])
        }

        guard currentUser == userType else {
            throw NSError(domain: "AuthError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Login set incorrect user type: expected \(userType), got \(currentUser)"
            ])
        }

        print("DEBUG: AuthenticatedUserTrait.prepare() completed successfully")
    }
}

// Mock authentication manager for the example
class AuthManager {
    static let shared = AuthManager()
    private init() {}

    private var isAuthenticated = false
    private var currentUserType: AuthenticatedUserTrait.UserType?

    func canAuthenticate() async -> Bool {
        // In a real implementation, check if auth services are available
        return true
    }

    func loginRegularUser() async {
        isAuthenticated = true
        currentUserType = .standard
        print("DEBUG: AuthManager set to standard user")
    }

    func loginPremiumUser() async {
        isAuthenticated = true
        currentUserType = .standard
        print("DEBUG: AuthManager set to standard (premium) user")
    }

    func loginAdminUser() async {
        isAuthenticated = true
        currentUserType = .admin
        print("DEBUG: AuthManager set to admin user")
    }

    func logout() async {
        isAuthenticated = false
        currentUserType = nil
        print("DEBUG: AuthManager logged out")
    }

    func currentUser() -> AuthenticatedUserTrait.UserType? {
        print("DEBUG: AuthManager.currentUser() returning \(String(describing: currentUserType))")
        return currentUserType
    }

    // Add method to allow AuthService to update the state
    func setUserType(_ type: AuthenticatedUserTrait.UserType?) {
        currentUserType = type
        isAuthenticated = type != nil
        print("DEBUG: AuthManager.setUserType() set to \(String(describing: type))")
    }
}

// ===========================================================================================
//  EXAMPLE 2: DATABASE TRANSACTION TRAIT
// ===========================================================================================

/// A trait that wraps tests in a database transaction that gets rolled back after the test
struct DatabaseTransactionTrait: TestTrait {
    // MARK: - Properties

    let comments: [Comment] = []

    var description: String {
        "Runs test in a database transaction that is rolled back"
    }

    // MARK: - TestTrait Implementation

    func prepare(for test: Test) async throws {
        print("DEBUG: DatabaseTransactionTrait.prepare() started for test: \(test.name)")

        // Begin a transaction in the database
        try await Database.shared.beginTransaction()
        print("DEBUG: DatabaseTransactionTrait.prepare() completed successfully")
    }
}

// Mock database manager for the example
class DatabaseManager {
    static let shared = DatabaseManager()
    private init() {}

    func beginTransaction() async throws {
        // In a real implementation, this would start a real DB transaction
        print("DB Transaction started")
    }

    func rollbackTransaction() async throws {
        // In a real implementation, this would roll back a real DB transaction
        print("DB Transaction rolled back")
    }

    func commitTransaction() async throws {
        // In a real implementation, this would commit a real DB transaction
        print("DB Transaction committed")
    }
}

// ===========================================================================================
//  EXAMPLE 3: LOCALE TESTING TRAIT
// ===========================================================================================

/// A trait that temporarily changes the app's locale for testing localization
struct LocaleTrait: TestTrait {
    // MARK: - Properties

    let localeIdentifier: String
    let comments: [Comment]

    var description: String {
        "Testing with locale '\(localeIdentifier)'"
    }

    // MARK: - Initialization

    init(_ localeIdentifier: String, _ comment: Comment? = nil) {
        print("DEBUG: Creating LocaleTrait with locale: \(localeIdentifier)")
        self.localeIdentifier = localeIdentifier
        self.comments = comment.map { [$0] } ?? []
    }

    // MARK: - TestTrait Implementation

    func prepare(for test: Test) async throws {
        print("DEBUG: LocaleTrait.prepare() started for test: \(test.name)")

        // Reset locale first
        LocaleManager.shared.resetToDefault()

        // Set the locale for this test
        print("DEBUG: Setting locale to '\(localeIdentifier)'")
        LocaleManager.shared.setLocale(localeIdentifier)

        // Verify locale was set correctly
        let currentLocale = LocaleManager.shared.currentLocale
        guard currentLocale == localeIdentifier else {
            throw NSError(domain: "LocaleError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to set locale: expected \(localeIdentifier), got \(currentLocale)"
            ])
        }

        print("DEBUG: LocaleTrait.prepare() completed successfully with locale: \(localeIdentifier)")
    }
}

// Mock locale manager for the example
class LocaleManager {
    static let shared = LocaleManager()
    private(set) var currentLocale: String = "en_US"
    private var lastSetLocale: String = "en_US"

    private init() {}

    func setLocale(_ identifier: String) {
        print("DEBUG: LocaleManager.setLocale() called with locale: \(identifier)")
        currentLocale = identifier
        lastSetLocale = identifier
    }

    // Helper extension to make String work like Locale
    func isLocale(_ locale: String, startsWith prefix: String) -> Bool {
        return locale.starts(with: prefix)
    }

    // Get the last explicitly set locale (for debugging)
    func getLastSetLocale() -> String {
        return lastSetLocale
    }

    // Reset to default locale
    func resetToDefault() {
        currentLocale = "en_US"
        lastSetLocale = "en_US"
        print("DEBUG: Reset locale to default en_US")
    }
}

// ===========================================================================================
//  REGISTERING CUSTOM TRAITS WITH THE TEST API
// ===========================================================================================

// This is how you expose your custom traits through a clean, discoverable API
extension Trait where Self == AuthenticatedUserTrait {
    static func authenticatedUser(as userType: AuthenticatedUserTrait.UserType = .standard) -> AuthenticatedUserTrait {
        AuthenticatedUserTrait(as: userType)
    }
}

extension Trait where Self == LocaleTrait {
    static func locale(_ identifier: String) -> LocaleTrait {
        LocaleTrait(identifier)
    }
}

extension Trait where Self == DatabaseTransactionTrait {
    static var databaseTransaction: DatabaseTransactionTrait {
        DatabaseTransactionTrait()
    }
}

// ===========================================================================================
//  USING CUSTOM TRAITS IN TESTS
// ===========================================================================================

struct CustomTraitsUsageExamples {
    // Example: Test that requires an authenticated admin user
    @Test(.authenticatedUser(as: .admin))
    func adminCanDeleteUsers() async throws {
        print("DEBUG: Starting adminCanDeleteUsers test")

        // Set up defer for cleanup first
        defer {
            print("DEBUG: adminCanDeleteUsers - running defer block")
            try? AuthService.shared.logout()
        }

        // Verify auth state before proceeding
        guard let currentUser = AuthManager.shared.currentUser() else {
            throw NSError(domain: "TestError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Current user is nil - trait setup failed"
            ])
        }

        print("DEBUG: Current user type: \(currentUser)")
        #expect(currentUser == .admin, "Current user should be admin but was \(currentUser)")

        let userManager = UserManager()

        // The trait has already authenticated as an admin
        let canDelete = userManager.currentUserCanDeleteOthers()

        // Assert admin privileges work
        #expect(canDelete)
        #expect(AuthManager.shared.currentUser() == .admin)
    }

    // Example: Test using an isolated database transaction
    @Test(.databaseTransaction)
    func savingUserProfileWorks() async throws {
        // Set up defer for cleanup first
        defer { Task { try? await Database.shared.rollbackTransaction() } }

        let profile = UserProfile(name: "Test User", email: "test@example.com")
        let repository = UserRepository()

        // Save data within the transaction
        try await repository.saveProfile(profile)
        let savedProfile = try await repository.getProfile(email: "test@example.com")

        // Verify save worked
        #expect(savedProfile?.name == "Test User")

        // After test completes, the transaction will be rolled back automatically
        // so no test data remains in the database
    }
}

// ===========================================================================================
//  PRACTICAL USE CASES FOR CUSTOM TRAITS
// ===========================================================================================

/*
 When should you use custom traits in your projects?

 1. SHARED TEST SETUP
    - User authentication states (logged in, specific permission levels, etc)
    - Feature flag configurations (A/B tests, beta features, etc)
    - Environment setup (dev, staging, prod API environments)

 2. RESOURCE MANAGEMENT
    - Database transactions that roll back after tests
    - File creation that gets cleaned up automatically
    - Network mocking that gets reset after each test

 3. TEST ENVIRONMENT CONTROL
    - Testing different locales/languages
    - Testing different device states (dark mode, accessibility settings)
    - Testing network conditions (online, offline, throttled)

 4. CONDITIONAL TESTING
    - Skip tests on certain platforms or OS versions
    - Skip tests when specific hardware isn't available
    - Skip tests in certain environments

 Custom traits are most valuable when:

 1. You have setup code used across many tests
 2. Your setup requires proper cleanup afterward
 3. Tests require specific conditions to run properly
 4. You want tests to remain focused on assertions, not setup
 */

// ===========================================================================================
//  BUILDING YOUR OWN TRAITS: A CHECKLIST
// ===========================================================================================

/*
 When creating your own custom traits, follow these best practices:

 1. SINGLE RESPONSIBILITY
    - Each trait should do one thing and do it well
    - Don't try to combine multiple responsibilities in one trait

 2. PROPER CLEANUP
    - Always register teardown blocks for cleanup
    - Restore the original state when the test finishes

 3. CLEAR FAILURES
    - Add clear error messages using Issue.record()
    - Throw XCTSkip with informative messages

 4. DISCOVERABLE API
    - Add extensions on Test with descriptive method names
    - Include documentation comments for your team

 5. ROBUST IMPLEMENTATION
    - Handle edge cases and error conditions
    - Verify your trait works in all expected environments
 */

// ===========================================================================================
//  MOCK TYPES FOR THE EXAMPLES
// ===========================================================================================

class UserManager {
    func currentUserCanDeleteOthers() -> Bool {
        print("DEBUG: UserManager.currentUserCanDeleteOthers() - current user: \(String(describing: AuthManager.shared.currentUser()))")
        let isAdmin = AuthManager.shared.currentUser() == .admin
        print("DEBUG: isAdmin = \(isAdmin)")
        return isAdmin
    }
}

struct UserProfile {
    let name: String
    let email: String
}

class UserRepository {
    private var profiles: [String: UserProfile] = [:]

    func saveProfile(_ profile: UserProfile) async throws {
        profiles[profile.email] = profile
    }

    func getProfile(email: String) async throws -> UserProfile? {
        return profiles[email]
    }
}

class WelcomeScreen {
    func getHeaderText() -> String {
        let locale = LocaleManager.shared.currentLocale
        if LocaleManager.shared.isLocale(locale, startsWith: "fr") {
            return "Bienvenue"
        } else if LocaleManager.shared.isLocale(locale, startsWith: "ja") {
            return "ようこそ"
        } else {
            return "Welcome"
        }
    }

    func getStartButtonText() -> String {
        let locale = LocaleManager.shared.currentLocale
        if LocaleManager.shared.isLocale(locale, startsWith: "fr") {
            return "Commencer"
        } else if LocaleManager.shared.isLocale(locale, startsWith: "ja") {
            return "始める"
        } else {
            return "Get Started"
        }
    }
}

class UserSettings {
    func getAvailableOptions() -> [String] {
        let locale = LocaleManager.shared.currentLocale
        let isStandard = AuthManager.shared.currentUser() == .standard

        var options: [String] = []

        if LocaleManager.shared.isLocale(locale, startsWith: "ja") {
            options.append("プロフィール設定") // Profile Settings
            options.append("通知設定") // Notification Settings

            if isStandard {
                options.append("プレミアム設定") // Premium Settings
            }
        } else {
            options.append("Profile Settings")
            options.append("Notification Settings")

            if isStandard {
                options.append("Premium Settings")
            }
        }

        return options
    }

    func getSaveButtonText() -> String {
        let locale = LocaleManager.shared.currentLocale
        if LocaleManager.shared.isLocale(locale, startsWith: "fr") {
            return "Enregistrer"
        } else if LocaleManager.shared.isLocale(locale, startsWith: "ja") {
            return "保存"
        } else {
            return "Save"
        }
    }
}

// ===========================================================================================
// NECESSARY INFRASTRUCTURE - MOCKS
// ===========================================================================================

// Mock auth service
class AuthService {
    static let shared = AuthService()
    private var isAuthenticated = false
    private var currentUserType: AuthenticatedUserTrait.UserType?

    private init() {}

    func login(username: String, password: String) async throws {
        print("DEBUG: AuthService.login() called with username: \(username)")

        // Clean prior state
        isAuthenticated = false
        currentUserType = nil

        // First update AuthManager
        if username.contains("admin") {
            print("DEBUG: Setting admin user")
            currentUserType = .admin
            await AuthManager.shared.loginAdminUser()
        } else if username.contains("standard") {
            print("DEBUG: Setting standard user")
            currentUserType = .standard
            await AuthManager.shared.loginRegularUser()
        } else {
            print("DEBUG: Setting guest user")
            currentUserType = .guest
        }

        isAuthenticated = true

        // Verify login worked properly
        let managerType = AuthManager.shared.currentUser()
        print("DEBUG: After login - AuthService user: \(String(describing: currentUserType)), AuthManager user: \(String(describing: managerType))")

        if managerType != currentUserType {
            print("ERROR: Auth synchronization issue - AuthManager type (\(String(describing: managerType))) doesn't match AuthService type (\(String(describing: currentUserType)))")
            throw NSError(domain: "AuthError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to synchronize authentication state"
            ])
        }
    }

    func logout() throws {
        print("DEBUG: AuthService.logout() called")
        Task {
            await AuthManager.shared.logout()
        }

        isAuthenticated = false
        currentUserType = nil
    }

    func currentUser() -> AuthenticatedUserTrait.UserType? {
        return currentUserType
    }
}

// Mock database
class Database {
    static let shared = Database()
    private var inTransaction = false

    private init() {}

    func beginTransaction() async throws {
        inTransaction = true
    }

    func commitTransaction() async throws {
        inTransaction = false
    }

    func rollbackTransaction() async throws {
        inTransaction = false
    }
}

// Mock feature flag manager
class FeatureFlagManager {
    static let shared = FeatureFlagManager()
    private var flags: [String: Bool] = [:]

    private init() {}

    func isEnabled(_ flag: String) -> Bool {
        return flags[flag] ?? false
    }

    func setFlag(_ flag: String, enabled: Bool) {
        flags[flag] = enabled
    }
}

// ===========================================================================================
// A REAL-WORLD EXAMPLE: FEATURE FLAG TRAIT
// ===========================================================================================

// This is a practical example you might really use in a production app
struct FeatureFlagTrait: TestTrait {
    let flag: String
    let enabled: Bool
    let comments: [Comment]

    var description: String {
        "Sets feature flag '\(flag)' to \(enabled)"
    }

    init(flag: String, enabled: Bool, _ comment: Comment? = nil) {
        self.flag = flag
        self.enabled = enabled
        self.comments = comment.map { [$0] } ?? []
    }

    func prepare(for test: Test) async throws {
        // Store original state to restore after test
        let originalValue = FeatureFlagManager.shared.isEnabled(flag)

        // Set up the feature flag for this test
        print("Setting feature flag '\(flag)' to \(enabled) for test: \(test.name)")
        FeatureFlagManager.shared.setFlag(flag, enabled: enabled)

        // Since Swift Testing doesn't have XCTCleanup or addTeardownBlock,
        // we need to guide the test author to handle cleanup with defer

        print("IMPORTANT: Add the following defer block to your test:")
        print("defer { FeatureFlagManager.shared.setFlag(\"\(flag)\", enabled: \(originalValue)) }")

        // Note: In a real implementation, the trait author would document
        // that tests using this trait should include a defer block for cleanup
    }
}

// ===========================================================================================
// NETWORK CONDITION TRAIT FOR TESTING CONNECTIVITY STATES
// ===========================================================================================

// Mock network client
class NetworkClient {
    static let shared = NetworkClient()
    private var networkCondition: NetworkConditionTrait.Condition = .online

    private init() {}

    func setNetworkCondition(_ condition: NetworkConditionTrait.Condition) {
        networkCondition = condition
        print("Network condition set to: \(condition)")
    }

    func fetchData() async -> NetworkResponse {
        switch networkCondition {
        case .online:
            return NetworkResponse(data: "Fresh data", source: .network)
        case .offline:
            return NetworkResponse(data: "Cached data", source: .cache)
        case .throttled:
            return NetworkResponse(data: "Slow data", source: .network)
        }
    }
}

struct NetworkResponse {
    enum Source {
        case network
        case cache
    }

    let data: String
    let source: Source
}

struct NetworkConditionTrait: TestTrait {
    enum Condition {
        case online
        case offline
        case throttled
    }

    let condition: Condition
    let comment: String?

    var description: String {
        "Testing with network condition: \(condition)"
    }

    init(condition: Condition, comment: String? = nil) {
        self.condition = condition
        self.comment = comment
    }

    func prepare(for test: Test) async throws {
        print("Setting network condition to \(condition) for test: \(test.name)")
        NetworkClient.shared.setNetworkCondition(condition)

        print("IMPORTANT: Add cleanup code if needed in your test")
    }
}

// Extension to allow using dot syntax for network conditions
extension Trait where Self == NetworkConditionTrait {
    // Direct properties for common network conditions
    static var offline: NetworkConditionTrait {
        NetworkConditionTrait(condition: .offline)
    }

    static var online: NetworkConditionTrait {
        NetworkConditionTrait(condition: .online)
    }

    static var throttled: NetworkConditionTrait {
        NetworkConditionTrait(condition: .throttled)
    }

    // Method for when you need to provide a comment
    static func withNetworkCondition(_ condition: NetworkConditionTrait.Condition,
                                    _ comment: String? = nil) -> NetworkConditionTrait {
        NetworkConditionTrait(condition: condition, comment: comment)
    }
}

// Example test using the network condition trait with dot syntax
@Test(.offline) // Using the direct property
func offlineCachingTest() async throws {
    // No need to manually set up offline mode - the trait handles it!
    let apiClient = NetworkClient.shared
    let result = await apiClient.fetchData()
    #expect(result.source == .cache)
}

// Example test using the trait with a comment
@Test(.withNetworkCondition(.throttled, "Testing throttled connection behavior"), .disabled())
func throttledConnectionTest() async throws {
    let apiClient = NetworkClient.shared
    let result = await apiClient.fetchData()
    #expect(result.source == .network)
}

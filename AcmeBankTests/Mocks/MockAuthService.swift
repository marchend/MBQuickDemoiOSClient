import Foundation
@testable import AcmeBank

/// Configurable `AuthServiceProtocol` test double shared across the test
/// target. Returns (or throws) a canned `Result` and records what it was
/// called with — including a call count — so a test can assert the
/// ViewModel actually invoked the service (and how many times).
final class MockAuthService: AuthServiceProtocol {
    var result: Result<LoginResult, Error> = .success(
        LoginResult(token: "token-123", customerId: "cust-1", firstName: "Taylor")
    )

    private(set) var callCount = 0
    private(set) var receivedUsername: String?
    private(set) var receivedPassword: String?

    /// Invoked after the call is recorded but before it returns, so a test
    /// can observe state (e.g. `isLoading`, re-entrancy guards) while the
    /// request is "in flight".
    var whileInFlight: (() async -> Void)?

    func login(username: String, password: String) async throws -> LoginResult {
        callCount += 1
        receivedUsername = username
        receivedPassword = password
        await whileInFlight?()
        return try result.get()
    }
}

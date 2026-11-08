import Foundation
@testable import AcmeBank

/// Configurable `AuthServiceProtocol` test double shared across the test
/// target. Returns (or throws) a canned `Result` and records what it was
/// called with — including a call count — so a test can assert the
/// ViewModel actually invoked the service (and how many times).
///
/// COVERAGE BOUNDARY — what this double does NOT prove. It conforms to
/// `AuthServiceProtocol` and therefore short-circuits the entire wire path:
/// URL, HTTP method, JSON encoding/decoding and status-code → `AuthError`
/// mapping all live in `AuthService` + `APIClient` and are exercised only by
/// `AuthServiceTests`. Since every `LoginViewModelTests` case now injects
/// this mock, a green login suite proves the ViewModel's branching is
/// correct — not that our payload shape conforms to the published login
/// contract.
///
/// That remaining gap is real and tracked as MBQUIC-7: the types
/// `APIClient.post` actually decodes are hand-written (see the CONTRACT GAP
/// note in `AcmeBank/Networking/AuthService.swift`), and the fixture in
/// `AuthServiceTests` is hand-authored rather than captured from the Mock
/// Backend, so neither side can catch the contract moving first. When
/// MBQUIC-7 lands, that fixture should be a captured response — including
/// nulls on any optional field and the real enum spellings — and the DTOs
/// should be the generated ones. Do not widen this mock to cover the wire
/// shape; it cannot, by construction.
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

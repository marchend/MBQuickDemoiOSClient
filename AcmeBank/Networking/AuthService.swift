import Foundation

/// The result of a successful login.
struct LoginResult: Equatable {
    let token: String
    let customerId: String
    let firstName: String
}

/// Errors surfaced by `AuthServiceProtocol.login`. Deliberately coarse —
/// `LoginViewModel` only needs to distinguish "bad credentials" from
/// "anything else went wrong" to pick the right inline message.
enum AuthError: Error, Equatable {
    case invalidCredentials
    case server
}

/// Abstraction over authentication so `LoginViewModel` can depend on a
/// protocol (and be unit-tested against a stub) instead of concrete
/// networking.
protocol AuthServiceProtocol {
    func login(username: String, password: String) async throws -> LoginResult
}

// MARK: - Wire DTOs
//
// CONTRACT GAP (raised in PR #1 review, MBQUIC-7): these two types are
// hand-written stand-ins for the `acme-mock-backend-login-v1` payloads, and
// `LoginResponse` is what `APIClient.post` actually decodes at runtime.
//
// They are NOT generated, and they are NOT checked against the published
// contract: the generated tree `Generated/acme-mock-backend-login-v1/` does
// not exist at this head (confirmed by searching the whole worktree — the
// string `acme-mock-backend-login-v1` appears nowhere but in this comment),
// so there is no symbol to import and nothing for the codegen conformance
// gate to bind to. Until that tree is committed and added to the app target
// in `project.yml`, a contract change (renamed key, newly nullable field,
// added enum case) will NOT fail the build.
//
// Interim guard: `AuthServiceTests` drives the real decode path through
// `APIClient` with the documented payload, so an accidental rename on OUR
// side fails the suite. That is a regression test, not a conformance test —
// it cannot catch the backend moving first. Replace both types with the
// generated ones as soon as the tree lands.

/// Request body for `POST /api/login`: `{ "username", "password" }`.
private struct LoginRequest: Encodable {
    let username: String
    let password: String
}

/// Success response body for `POST /api/login`:
/// `{ "token", "customerId", "firstName" }`.
private struct LoginResponse: Decodable {
    let token: String
    let customerId: String
    let firstName: String
}

/// Live implementation of `AuthServiceProtocol`, backed by `APIClient`.
struct AuthService: AuthServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func login(username: String, password: String) async throws -> LoginResult {
        let requestBody = LoginRequest(username: username, password: password)

        do {
            let response: LoginResponse = try await apiClient.post(
                path: "/api/login",
                body: requestBody
            )
            return LoginResult(
                token: response.token,
                customerId: response.customerId,
                firstName: response.firstName
            )
        } catch APIError.unauthorized {
            throw AuthError.invalidCredentials
        } catch {
            throw AuthError.server
        }
    }
}

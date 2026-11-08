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

/// Request body for `POST /api/login`, matching the Mock Backend's contract
/// exactly: `{ "username", "password" }`.
private struct LoginRequest: Encodable {
    let username: String
    let password: String
}

/// Success response body for `POST /api/login`, matching the Mock Backend's
/// contract exactly: `{ "token", "customerId", "firstName" }`.
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

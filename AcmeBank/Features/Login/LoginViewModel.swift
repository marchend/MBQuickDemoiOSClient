import Foundation

/// Drives `LoginView`. Owns all mutable/network state; the view is a dumb,
/// declarative projection of this object's `@Published` properties.
@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username: String = "" {
        didSet { errorMessage = nil }
    }

    @Published var password: String = "" {
        didSet { errorMessage = nil }
    }

    @Published var isPasswordVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let authService: AuthServiceProtocol
    private let sessionStore: SessionStore

    init(authService: AuthServiceProtocol = AuthService(), sessionStore: SessionStore) {
        self.authService = authService
        self.sessionStore = sessionStore
    }

    /// The Sign in button is enabled only once both fields are non-empty.
    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    func signIn() async {
        guard isSignInEnabled, !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await authService.login(username: username, password: password)
            sessionStore.signIn(
                Session(
                    token: result.token,
                    customerId: result.customerId,
                    firstName: result.firstName
                )
            )
        } catch AuthError.invalidCredentials {
            errorMessage = "Incorrect username or password. Please try again."
        } catch {
            errorMessage = "Unable to reach the server. Please try again."
        }
    }
}

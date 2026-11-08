import XCTest
@testable import AcmeBank

/// Covers the branching logic in `LoginViewModel.signIn()` — error mapping,
/// loading state, the session hand-off that flips `RootView`, and the
/// re-entrancy guard. `AuthServiceProtocol` exists precisely so this can be
/// done against a stub with no network.
@MainActor
final class LoginViewModelTests: XCTestCase {

    // MARK: - Success

    func test_signIn_onSuccess_populatesSessionAndClearsLoading() async {
        let stub = StubAuthService()
        let sessionStore = SessionStore()
        let viewModel = makeViewModel(authService: stub, sessionStore: sessionStore)

        await viewModel.signIn()

        XCTAssertEqual(stub.receivedUsername, "bankuser.one@acmebank.com")
        XCTAssertEqual(stub.receivedPassword, "Password123")
        XCTAssertEqual(
            sessionStore.session,
            Session(token: "token-123", customerId: "cust-1", firstName: "Taylor")
        )
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Error mapping

    func test_signIn_onInvalidCredentials_showsCredentialsMessageAndNoSession() async {
        let stub = StubAuthService()
        stub.result = .failure(AuthError.invalidCredentials)
        let sessionStore = SessionStore()
        let viewModel = makeViewModel(authService: stub, sessionStore: sessionStore)

        await viewModel.signIn()

        XCTAssertEqual(
            viewModel.errorMessage,
            "Incorrect username or password. Please try again."
        )
        XCTAssertNil(sessionStore.session)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_signIn_onServerError_showsUnreachableMessage() async {
        let stub = StubAuthService()
        stub.result = .failure(AuthError.server)
        let sessionStore = SessionStore()
        let viewModel = makeViewModel(authService: stub, sessionStore: sessionStore)

        await viewModel.signIn()

        XCTAssertEqual(
            viewModel.errorMessage,
            "Unable to reach the server. Please try again."
        )
        XCTAssertNil(sessionStore.session)
    }

    /// Anything the service throws that isn't an `AuthError` still has to
    /// land on the generic message rather than escaping uncaught.
    func test_signIn_onUnexpectedError_showsUnreachableMessage() async {
        let stub = StubAuthService()
        stub.result = .failure(URLError(.notConnectedToInternet))
        let viewModel = makeViewModel(authService: stub, sessionStore: SessionStore())

        await viewModel.signIn()

        XCTAssertEqual(
            viewModel.errorMessage,
            "Unable to reach the server. Please try again."
        )
    }

    /// A stale error must not survive the next attempt.
    func test_signIn_clearsPreviousErrorBeforeRetrying() async {
        let stub = StubAuthService()
        stub.result = .failure(AuthError.invalidCredentials)
        let sessionStore = SessionStore()
        let viewModel = makeViewModel(authService: stub, sessionStore: sessionStore)

        await viewModel.signIn()
        XCTAssertNotNil(viewModel.errorMessage)

        stub.result = .success(
            LoginResult(token: "token-123", customerId: "cust-1", firstName: "Taylor")
        )
        await viewModel.signIn()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(sessionStore.session)
    }

    // MARK: - Loading state

    func test_signIn_isLoadingIsTrueInFlight_andClearedOnSuccess() async {
        let stub = StubAuthService()
        let viewModel = makeViewModel(authService: stub, sessionStore: SessionStore())
        let loadingInFlight = Box(false)
        stub.whileInFlight = {
            await MainActor.run { loadingInFlight.value = viewModel.isLoading }
        }

        await viewModel.signIn()

        XCTAssertTrue(loadingInFlight.value, "isLoading should be true while the call is in flight")
        XCTAssertFalse(viewModel.isLoading, "the defer should clear isLoading on success")
    }

    func test_signIn_isLoadingIsClearedWhenTheCallThrows() async {
        let stub = StubAuthService()
        stub.result = .failure(AuthError.server)
        let viewModel = makeViewModel(authService: stub, sessionStore: SessionStore())
        let loadingInFlight = Box(false)
        stub.whileInFlight = {
            await MainActor.run { loadingInFlight.value = viewModel.isLoading }
        }

        await viewModel.signIn()

        XCTAssertTrue(loadingInFlight.value)
        XCTAssertFalse(viewModel.isLoading, "the defer should clear isLoading on throw too")
    }

    // MARK: - Guards

    func test_isSignInEnabled_requiresBothFields() {
        let viewModel = LoginViewModel(authService: StubAuthService(), sessionStore: SessionStore())

        XCTAssertFalse(viewModel.isSignInEnabled)

        viewModel.username = "bankuser.one@acmebank.com"
        XCTAssertFalse(viewModel.isSignInEnabled, "username alone is not enough")

        viewModel.password = "Password123"
        XCTAssertTrue(viewModel.isSignInEnabled)
    }

    func test_signIn_withEmptyFields_doesNotCallTheService() async {
        let stub = StubAuthService()
        let viewModel = LoginViewModel(authService: stub, sessionStore: SessionStore())

        await viewModel.signIn()

        XCTAssertEqual(stub.callCount, 0)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// The `!isLoading` half of the guard: a second tap while the first
    /// request is still in flight must be dropped, not duplicated.
    func test_signIn_whileAlreadyInFlight_doesNotIssueASecondRequest() async {
        let stub = StubAuthService()
        let viewModel = makeViewModel(authService: stub, sessionStore: SessionStore())
        stub.whileInFlight = {
            await viewModel.signIn()
        }

        await viewModel.signIn()

        XCTAssertEqual(stub.callCount, 1)
    }

    // MARK: - Helpers

    /// A ViewModel with both fields already filled, i.e. `isSignInEnabled`.
    private func makeViewModel(
        authService: AuthServiceProtocol,
        sessionStore: SessionStore
    ) -> LoginViewModel {
        let viewModel = LoginViewModel(authService: authService, sessionStore: sessionStore)
        viewModel.username = "bankuser.one@acmebank.com"
        viewModel.password = "Password123"
        return viewModel
    }
}

/// Records what the ViewModel asked for and returns a canned result, with a
/// hook that runs *inside* the call so a test can observe in-flight state.
private final class StubAuthService: AuthServiceProtocol {
    var result: Result<LoginResult, Error> = .success(
        LoginResult(token: "token-123", customerId: "cust-1", firstName: "Taylor")
    )

    private(set) var callCount = 0
    private(set) var receivedUsername: String?
    private(set) var receivedPassword: String?

    /// Invoked after the call is recorded but before it returns.
    var whileInFlight: (() async -> Void)?

    func login(username: String, password: String) async throws -> LoginResult {
        callCount += 1
        receivedUsername = username
        receivedPassword = password
        await whileInFlight?()
        return try result.get()
    }
}

/// Reference-typed box so an escaping stub callback can hand an observation
/// back to the test body.
private final class Box<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

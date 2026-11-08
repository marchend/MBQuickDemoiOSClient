import XCTest
@testable import AcmeBank

/// Covers the branching logic in `LoginViewModel.signIn()` — error mapping,
/// loading state, the session hand-off that flips `RootView`, and the
/// re-entrancy guard. `AuthServiceProtocol` exists precisely so this can be
/// done against a stub with no network.
@MainActor
final class LoginViewModelTests: XCTestCase {

    // MARK: - isSignInEnabled

    func test_isSignInEnabled_falseWhenEitherFieldEmpty() {
        let viewModel = LoginViewModel(authService: MockAuthService(), sessionStore: SessionStore())

        XCTAssertFalse(viewModel.isSignInEnabled, "both fields empty")

        viewModel.username = "bankuser.one@acmebank.com"
        XCTAssertFalse(viewModel.isSignInEnabled, "username alone is not enough")

        viewModel.username = ""
        viewModel.password = "Password123"
        XCTAssertFalse(viewModel.isSignInEnabled, "password alone is not enough")
    }

    func test_isSignInEnabled_trueWhenBothFieldsNonEmpty() {
        let viewModel = LoginViewModel(authService: MockAuthService(), sessionStore: SessionStore())

        viewModel.username = "bankuser.one@acmebank.com"
        viewModel.password = "Password123"

        XCTAssertTrue(viewModel.isSignInEnabled)
    }

    /// Pins the whitespace-only semantics, which the AC ("both fields
    /// non-empty") leaves open. `isSignInEnabled` is a plain `isEmpty` check
    /// (LoginViewModel.swift:28-30), so `"   "` counts as filled: Sign in is
    /// enabled, the empty-field guard in `signIn()` does not fire, and the
    /// value goes to `/api/login` untrimmed — the backend stays the authority
    /// on whether it is a valid credential.
    ///
    /// This is the behaviour we intend today, asserted so it is not merely
    /// incidental: adding `trimmingCharacters(in: .whitespaces)` later must
    /// fail here and be a deliberate, reviewed change rather than a silent one.
    func test_isSignInEnabled_treatsWhitespaceOnlyInputAsFilled_andSendsItUntrimmed() async {
        let stub = MockAuthService()
        let viewModel = LoginViewModel(authService: stub, sessionStore: SessionStore())

        viewModel.username = "   "
        viewModel.password = "\t"

        XCTAssertTrue(
            viewModel.isSignInEnabled,
            "whitespace is deliberately not trimmed before the empty check"
        )

        await viewModel.signIn()

        XCTAssertEqual(
            stub.callCount,
            1,
            "the empty-field guard does not treat whitespace-only input as empty"
        )
        XCTAssertEqual(stub.receivedUsername, "   ", "username is forwarded untrimmed")
        XCTAssertEqual(stub.receivedPassword, "\t", "password is forwarded untrimmed")
    }

    // MARK: - Success

    func test_signIn_success_storesSessionInSessionStore() async {
        let stub = MockAuthService()
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

    func test_signIn_invalidCredentials_setsIncorrectCredentialsMessage() async {
        let stub = MockAuthService()
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

    func test_signIn_networkOrServerError_setsUnreachableMessage() async {
        let stub = MockAuthService()
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

    /// Anything the service throws that isn't an `AuthError` — e.g. a raw
    /// transport failure — still has to land on the generic message rather
    /// than escaping uncaught.
    func test_signIn_onUnexpectedTransportError_setsUnreachableMessage() async {
        let stub = MockAuthService()
        stub.result = .failure(URLError(.notConnectedToInternet))
        let viewModel = makeViewModel(authService: stub, sessionStore: SessionStore())

        await viewModel.signIn()

        XCTAssertEqual(
            viewModel.errorMessage,
            "Unable to reach the server. Please try again."
        )
    }

    // MARK: - Error clearing

    func test_errorMessage_clearsOnFieldEdit() async {
        let stub = MockAuthService()
        stub.result = .failure(AuthError.invalidCredentials)
        let viewModel = makeViewModel(authService: stub, sessionStore: SessionStore())

        await viewModel.signIn()
        XCTAssertNotNil(viewModel.errorMessage, "precondition: an error is showing")

        viewModel.username = "someone-else@acmebank.com"
        XCTAssertNil(viewModel.errorMessage, "editing username should clear the error")

        await viewModel.signIn()
        XCTAssertNotNil(viewModel.errorMessage, "precondition: an error is showing again")

        viewModel.password = "AnotherPassword1"
        XCTAssertNil(viewModel.errorMessage, "editing password should clear the error")
    }

    /// A stale error must not survive the next attempt.
    func test_signIn_clearsPreviousErrorBeforeRetrying() async {
        let stub = MockAuthService()
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
        let stub = MockAuthService()
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
        let stub = MockAuthService()
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

    func test_signIn_withEmptyFields_doesNotCallTheService() async {
        let stub = MockAuthService()
        let viewModel = LoginViewModel(authService: stub, sessionStore: SessionStore())

        await viewModel.signIn()

        XCTAssertEqual(stub.callCount, 0)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// The `!isLoading` half of the guard: a second tap while the first
    /// request is still in flight must be dropped, not duplicated.
    func test_signIn_whileAlreadyInFlight_doesNotIssueASecondRequest() async {
        let stub = MockAuthService()
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

/// Reference-typed box so an escaping stub callback can hand an observation
/// back to the test body.
private final class Box<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

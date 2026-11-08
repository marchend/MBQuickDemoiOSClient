import XCTest
@testable import AcmeBank

/// Coverage for `SessionStore`, the source of truth `RootView` branches on.
/// The login flow's own branching logic is covered by `LoginViewModelTests`
/// and `AuthServiceTests` in this target.
final class SessionStoreTests: XCTestCase {
    @MainActor
    func test_initialSession_isNil() {
        let store = SessionStore()

        XCTAssertNil(store.session)
    }

    @MainActor
    func test_signIn_setsSession() {
        let store = SessionStore()
        let session = Session(token: "t", customerId: "c1", firstName: "Taylor")

        store.signIn(session)

        XCTAssertEqual(store.session, session)
    }

    @MainActor
    func test_signOut_clearsSession() {
        let store = SessionStore(session: Session(token: "t", customerId: "c1", firstName: "Taylor"))

        store.signOut()

        XCTAssertNil(store.session)
    }
}

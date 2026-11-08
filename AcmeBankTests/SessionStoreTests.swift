import XCTest
@testable import AcmeBank

/// Minimal smoke coverage for `SessionStore` — confirms the test target is
/// wired correctly (links against the app module) ahead of the dedicated
/// `LoginViewModelTests` suite that lands in the next PR.
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

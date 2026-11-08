import Foundation

/// An authenticated session established by a successful sign-in. Held only
/// in memory — no Keychain persistence (explicitly out of scope for this
/// story).
struct Session: Equatable {
    let token: String
    let customerId: String
    let firstName: String
}

/// Holds the current in-memory session, if any. The single source of truth
/// `RootView` branches on to decide between `LoginView` and the signed-in
/// destination.
@MainActor
final class SessionStore: ObservableObject {
    @Published var session: Session?

    init(session: Session? = nil) {
        self.session = session
    }

    func signIn(_ session: Session) {
        self.session = session
    }

    func signOut() {
        session = nil
    }
}

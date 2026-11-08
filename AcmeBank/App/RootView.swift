import SwiftUI

/// Root of the view hierarchy: shows `LoginView` when there is no session,
/// otherwise the signed-in placeholder (the real Landing Screen is a later
/// story — see `SignedInPlaceholderView`).
struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if let session = sessionStore.session {
                SignedInPlaceholderView(firstName: session.firstName)
            } else {
                LoginView(viewModel: LoginViewModel(sessionStore: sessionStore))
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(SessionStore())
}

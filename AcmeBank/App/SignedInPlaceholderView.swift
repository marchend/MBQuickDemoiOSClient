import SwiftUI

// SCAFFOLDING(MBQUIC-4): placeholder destination shown after a successful
// sign-in. The real Landing Screen is a later, dedicated story — this
// static view only exists so the end-to-end login flow is demonstrable
// until then.
struct SignedInPlaceholderView: View {
    let firstName: String

    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {
            Color.acmeBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Signed in as \(firstName)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.acmeNavy)

                Button("Sign out") {
                    sessionStore.signOut()
                }
                .font(.body.weight(.medium))
                .foregroundStyle(Color.acmeNavy)
            }
        }
    }
}

#Preview {
    SignedInPlaceholderView(firstName: "Taylor")
        .environmentObject(SessionStore())
}

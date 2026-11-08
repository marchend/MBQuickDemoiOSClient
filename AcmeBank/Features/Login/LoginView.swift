import SwiftUI

/// The login screen: static Okta-styled top strip, centred hexagon logo,
/// username/password fields, a "Keep me signed in" checkbox, and a
/// full-width Sign in button — bound to `LoginViewModel`. Matches
/// `updated_login_screen.png` (navy / white / grey only, no other hues).
struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel

    /// Purely cosmetic — not part of the sign-in contract, so it lives as
    /// view-local state rather than on the ViewModel.
    @State private var isKeepSignedInChecked = false

    private enum Field: Hashable {
        case username
        case password
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: 0) {
            topStrip

            ScrollView {
                VStack(spacing: 32) {
                    logo

                    VStack(spacing: 4) {
                        Text("Acme Bank")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.acmeNavy)
                        Text("Sign in to your account")
                            .font(.subheadline)
                            .foregroundStyle(Color.acmeMutedText)
                    }

                    formFields
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }

            footer
        }
        .background(Color.acmeBackground.ignoresSafeArea())
    }

    // MARK: - Top strip

    private var topStrip: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.acmeGreyText)
                Text("acmebank.okta.com")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.acmeGreyText)

                Spacer()

                OktaMarkView()
                    .frame(width: 18, height: 18)
                Text("okta")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.acmeNavy)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
        }
        .background(Color.white)
    }

    // MARK: - Logo

    private var logo: some View {
        HexagonShape()
            .fill(Color.acmeNavy)
            .frame(width: 84, height: 84)
            .overlay(
                Text("A")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    // MARK: - Form

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.acmeNavy)

                TextField("name@acmebank.com", text: $viewModel.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .username)
                    .fieldStyle()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.acmeNavy)

                HStack(spacing: 8) {
                    Group {
                        if viewModel.isPasswordVisible {
                            TextField("", text: $viewModel.password)
                        } else {
                            SecureField("", text: $viewModel.password)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .password)

                    Button {
                        viewModel.isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: viewModel.isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(Color.acmeGreyText)
                    }
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.acmeBorder, lineWidth: 1)
                )

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.acmeNavy)
                }
            }

            keepSignedInCheckbox

            signInButton
        }
    }

    private var keepSignedInCheckbox: some View {
        Button {
            isKeepSignedInChecked.toggle()
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isKeepSignedInChecked ? Color.acmeNavy : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.acmeBorder, lineWidth: 1.5)
                    )
                    .frame(width: 20, height: 20)

                Text("Keep me signed in")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.acmeNavy)
            }
        }
        .buttonStyle(.plain)
    }

    private var signInButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.signIn() }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Sign in")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.acmeNavy)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(viewModel.isSignInEnabled ? 1 : 0.5)
        }
        .disabled(!viewModel.isSignInEnabled || viewModel.isLoading)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Text("Secured by")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.acmeMutedText)
                OktaMarkView()
                    .frame(width: 16, height: 16)
                Text("okta")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.acmeMutedText)
            }
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
}

private extension View {
    /// Shared text-field chrome: white fill, rounded corners, light grey
    /// border — used by the username field.
    func fieldStyle() -> some View {
        self
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.acmeBorder, lineWidth: 1)
            )
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel(sessionStore: SessionStore()))
}

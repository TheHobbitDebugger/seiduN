import SwiftUI

/// Login/register mode for the authentication form.
private enum AuthMode: String, CaseIterable, Identifiable {
    /// Existing account login.
    case login

    /// New account registration.
    case register

    /// Required by SwiftUI's picker.
    var id: String {
        rawValue
    }

    /// Button title for the selected mode.
    var actionTitle: String {
        switch self {
        case .login:
            return "Log In"
        case .register:
            return "Create Account"
        }
    }
}

/// Account screen used before a session exists.
struct AuthenticationView: View {
    /// Shared session store that performs register/login.
    @EnvironmentObject private var sessionStore: SessionStore

    /// Selected authentication mode.
    @State private var mode: AuthMode = .login

    /// Username typed by the user.
    @State private var username = ""

    /// Password typed by the user.
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    Text("Log In").tag(AuthMode.login)
                    Text("Register").tag(AuthMode.register)
                }
                .pickerStyle(.segmented)

                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        if sessionStore.isWorking {
                            ProgressView()
                        } else {
                            Text(mode.actionTitle)
                        }
                    }
                    .disabled(sessionStore.isWorking)
                }
            }
            .navigationTitle("Private Vault")
            .alert("Account Error", isPresented: hasErrorMessage) {
                Button("OK", role: .cancel) {
                    sessionStore.errorMessage = nil
                }
            } message: {
                Text(sessionStore.errorMessage ?? "")
            }
        }
    }

    /// Converts the optional error string into a SwiftUI alert binding.
    private var hasErrorMessage: Binding<Bool> {
        Binding(
            get: { sessionStore.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    sessionStore.errorMessage = nil
                }
            }
        )
    }

    /// Starts the selected authentication request.
    private func submit() {
        Task {
            switch mode {
            case .login:
                await sessionStore.login(username: username, password: password)
            case .register:
                await sessionStore.register(username: username, password: password)
            }
        }
    }
}

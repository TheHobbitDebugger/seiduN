import SwiftUI

/// Simple account screen for the active session.
struct AccountView: View {
    /// Shared session store used to show the current user and log out.
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            Form {
                if let user = sessionStore.session?.user {
                    Section {
                        LabeledContent("Username", value: user.username)
                        LabeledContent("User ID", value: user.id)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await sessionStore.logout()
                        }
                    } label: {
                        if sessionStore.isWorking {
                            ProgressView()
                        } else {
                            Text("Log Out")
                        }
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

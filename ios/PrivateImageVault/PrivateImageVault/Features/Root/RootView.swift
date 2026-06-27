import SwiftUI

/// Chooses between authentication and the logged-in app.
///
/// This keeps account gating at the root instead of repeating login checks in
/// every feature screen.
struct RootView: View {
    /// Shared session state restored from Keychain or created by login/register.
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.isAuthenticated {
                AppHomeView()
            } else {
                AuthenticationView()
            }
        }
    }
}

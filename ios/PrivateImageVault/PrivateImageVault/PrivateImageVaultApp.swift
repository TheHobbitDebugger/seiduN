import SwiftUI

/// The application entry point.
///
/// SwiftUI starts here, creates the root scene, and injects the shared stores
/// used by capture, account/session state, and plaintext API calls.
@main
struct PrivateImageVaultApp: App {
    /// The image store owns the app-private file directory and publishes saved images.
    ///
    /// `@StateObject` keeps one store instance alive for the lifetime of the app UI.
    @StateObject private var imageStore = PrivateImageStore()

    /// API client used by session, send, and inbox flows.
    @StateObject private var apiClient: APIClient

    /// Session store owns login/register/logout state and Keychain persistence.
    @StateObject private var sessionStore: SessionStore

    /// Creates shared app services once at launch.
    @MainActor
    init() {
        let apiClient = APIClient(configuration: .localDevelopment)

        _apiClient = StateObject(wrappedValue: apiClient)
        _sessionStore = StateObject(wrappedValue: SessionStore(apiClient: apiClient))
    }

    var body: some Scene {
        WindowGroup {
            /// The root view decides whether to show auth or the logged-in app.
            ///
            /// Environment objects keep shared state out of individual view constructors.
            RootView()
                .environmentObject(imageStore)
                .environmentObject(apiClient)
                .environmentObject(sessionStore)
        }
    }
}

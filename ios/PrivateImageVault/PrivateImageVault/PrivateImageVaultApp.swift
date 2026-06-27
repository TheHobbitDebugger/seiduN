import SwiftUI

/// The application entry point.
///
/// SwiftUI starts here, creates the root scene, and injects the shared image
/// store so every screen reads and writes the same private app storage.
@main
struct PrivateImageVaultApp: App {
    /// The image store owns the app-private file directory and publishes saved images.
    ///
    /// `@StateObject` keeps one store instance alive for the lifetime of the app UI.
    @StateObject private var imageStore = PrivateImageStore()

    var body: some Scene {
        WindowGroup {
            /// The first screen is the private gallery.
            ///
            /// The gallery receives `imageStore` through the SwiftUI environment so later
            /// screens can access it without passing it through every initializer.
            GalleryView()
                .environmentObject(imageStore)
        }
    }
}

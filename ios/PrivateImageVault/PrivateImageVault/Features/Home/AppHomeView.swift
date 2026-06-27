import SwiftUI

/// Main logged-in app shell.
///
/// Tabs keep the first workflow simple: private local images, received messages,
/// and account controls.
struct AppHomeView: View {
    var body: some View {
        TabView {
            GalleryView()
                .tabItem {
                    Label("Vault", systemImage: "photo.stack")
                }

            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray")
                }

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
    }
}

import Foundation

/// Runtime settings for the backend API client.
struct APIConfiguration {
    /// Base URL for the Node.js plaintext API.
    let baseURL: URL

    /// Development API running on the Mac that hosts the iOS simulator.
    ///
    /// A physical iPhone needs the Mac's LAN IP address instead of 127.0.0.1.
    static let localDevelopment = APIConfiguration(
        baseURL: URL(string: "http://127.0.0.1:3000")!
    )
}

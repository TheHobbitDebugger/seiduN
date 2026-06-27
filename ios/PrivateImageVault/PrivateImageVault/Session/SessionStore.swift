import Combine
import Foundation

/// Owns local account/session state for the app.
///
/// Views talk to this store instead of handling bearer tokens directly. That
/// keeps authentication behavior auditable and contained.
@MainActor
final class SessionStore: ObservableObject {
    /// Current authenticated session, or nil when logged out.
    @Published private(set) var session: AuthSession?

    /// Whether an auth operation is currently running.
    @Published private(set) var isWorking = false

    /// Last user-visible account/session error.
    @Published var errorMessage: String?

    /// API client used to create and destroy sessions.
    private let apiClient: APIClient

    /// Keychain wrapper used to persist the session securely.
    private let keychain: KeychainStore

    /// Stable Keychain account name for the serialized session.
    private let sessionAccount = "api-session"

    /// JSON encoder for Keychain persistence.
    private let encoder = JSONEncoder()

    /// JSON decoder for Keychain restoration.
    private let decoder = JSONDecoder()

    /// Creates the store and restores any saved session from Keychain.
    init(apiClient: APIClient, keychain: KeychainStore = KeychainStore()) {
        self.apiClient = apiClient
        self.keychain = keychain
        restoreSession()
    }

    /// Whether the app has a local session token.
    var isAuthenticated: Bool {
        session != nil
    }

    /// Registers a new user and saves the returned session.
    func register(username: String, password: String) async {
        await authenticate {
            try await apiClient.register(username: username, password: password)
        }
    }

    /// Logs into an existing user and saves the returned session.
    func login(username: String, password: String) async {
        await authenticate {
            try await apiClient.login(username: username, password: password)
        }
    }

    /// Logs out locally and attempts to revoke the server-side session.
    func logout() async {
        isWorking = true
        defer {
            isWorking = false
        }

        do {
            try await apiClient.logout()
        } catch {
            /// Local logout still proceeds if the server is unreachable.
            /// Otherwise the user could get stuck with a dead local token.
        }

        clearSession()
    }

    /// Runs a register/login call and stores the resulting session.
    private func authenticate(_ operation: () async throws -> AuthSession) async {
        isWorking = true
        errorMessage = nil

        do {
            let newSession = try await operation()
            try saveSession(newSession)
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }

    /// Saves the session in memory, Keychain, and the API client.
    private func saveSession(_ newSession: AuthSession) throws {
        let data = try encoder.encode(newSession)
        try keychain.save(data, account: sessionAccount)

        session = newSession
        apiClient.setAuthToken(newSession.token)
    }

    /// Restores a previously saved session from Keychain.
    private func restoreSession() {
        guard let data = try? keychain.readData(account: sessionAccount),
              let storedSession = try? decoder.decode(AuthSession.self, from: data) else {
            return
        }

        session = storedSession
        apiClient.setAuthToken(storedSession.token)
    }

    /// Removes the local session from memory, Keychain, and the API client.
    private func clearSession() {
        try? keychain.delete(account: sessionAccount)
        session = nil
        apiClient.setAuthToken(nil)
    }
}

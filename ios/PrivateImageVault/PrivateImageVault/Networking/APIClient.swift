import Combine
import Foundation

/// Thin `URLSession` client for the plaintext Node.js API.
///
/// This client owns HTTP details only: URLs, headers, JSON encoding/decoding, and
/// binary upload/download. Session persistence lives in `SessionStore`.
@MainActor
final class APIClient: ObservableObject {
    /// API host and base path configuration.
    private let configuration: APIConfiguration

    /// The system URL session used for network requests.
    private let urlSession: URLSession

    /// Current bearer token. This is set by `SessionStore` after login or restore.
    private var authToken: String?

    /// JSON encoder used for request bodies.
    private let encoder = JSONEncoder()

    /// JSON decoder used for API responses.
    private let decoder = JSONDecoder()

    /// Creates the API client.
    init(
        configuration: APIConfiguration = .localDevelopment,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    /// Updates the bearer token used by protected API calls.
    func setAuthToken(_ token: String?) {
        authToken = token
    }

    /// Registers a new account and returns the authenticated session.
    func register(username: String, password: String) async throws -> AuthSession {
        let response: AuthResponse = try await sendJSON(
            method: "POST",
            path: "/v1/auth/register",
            body: AuthRequest(username: username, password: password),
            requiresAuth: false
        )

        return response.session
    }

    /// Logs into an existing account and returns the authenticated session.
    func login(username: String, password: String) async throws -> AuthSession {
        let response: AuthResponse = try await sendJSON(
            method: "POST",
            path: "/v1/auth/login",
            body: AuthRequest(username: username, password: password),
            requiresAuth: false
        )

        return response.session
    }

    /// Logs out the current token on the backend.
    func logout() async throws {
        let _: APIStatusResponse = try await sendJSON(
            method: "POST",
            path: "/v1/auth/logout",
            requiresAuth: true
        )
    }

    /// Loads the current user's profile for the stored token.
    func me() async throws -> APIUser {
        let response: MeResponse = try await sendJSON(
            method: "GET",
            path: "/v1/auth/me",
            requiresAuth: true
        )

        return response.user
    }

    /// Searches users by username prefix.
    func searchUsers(username: String) async throws -> [APIUser] {
        var components = URLComponents()
        components.path = "/v1/users/search"
        components.queryItems = [
            URLQueryItem(name: "username", value: username)
        ]

        guard let path = components.string else {
            throw APIClientError.invalidURL
        }

        let response: UserSearchResponse = try await sendJSON(
            method: "GET",
            path: path,
            requiresAuth: true
        )

        return response.users
    }

    /// Uploads raw image bytes to the plaintext object endpoint.
    func uploadObject(data: Data, contentType: String) async throws -> APIObject {
        var request = try makeRequest(
            method: "POST",
            path: "/v1/objects",
            requiresAuth: true
        )

        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await urlSession.data(for: request)
        let uploadResponse: ObjectUploadResponse = try decode(responseData, response: response)

        return uploadResponse.object
    }

    /// Downloads raw image bytes for an object id.
    func downloadObject(objectId: String) async throws -> Data {
        let request = try makeRequest(
            method: "GET",
            path: "/v1/objects/\(objectId)",
            requiresAuth: true
        )

        let (data, response) = try await urlSession.data(for: request)

        try validateBinaryResponse(data, response: response)

        return data
    }

    /// Creates a message pointing to an uploaded object.
    func createImageMessage(recipientUserId: String, objectId: String) async throws -> ImageMessage {
        let response: ImageMessageResponse = try await sendJSON(
            method: "POST",
            path: "/v1/image-messages",
            body: CreateImageMessageRequest(recipientUserId: recipientUserId, objectId: objectId),
            requiresAuth: true
        )

        return response.message
    }

    /// Loads received image messages.
    func inbox() async throws -> [ImageMessage] {
        let response: ImageMessagesResponse = try await sendJSON(
            method: "GET",
            path: "/v1/image-messages/inbox",
            requiresAuth: true
        )

        return response.messages
    }

    /// Marks a message as delivered.
    func markDelivered(messageId: String) async throws -> ImageMessage {
        let response: ImageMessageResponse = try await sendJSON(
            method: "POST",
            path: "/v1/image-messages/\(messageId)/delivered",
            requiresAuth: true
        )

        return response.message
    }

    /// Marks a message as seen.
    func markSeen(messageId: String) async throws -> ImageMessage {
        let response: ImageMessageResponse = try await sendJSON(
            method: "POST",
            path: "/v1/image-messages/\(messageId)/seen",
            requiresAuth: true
        )

        return response.message
    }

    /// Sends a JSON request with an encodable body.
    private func sendJSON<Body: Encodable, Response: Decodable>(
        method: String,
        path: String,
        body: Body,
        requiresAuth: Bool
    ) async throws -> Response {
        var request = try makeRequest(
            method: method,
            path: path,
            requiresAuth: requiresAuth
        )

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await urlSession.data(for: request)

        return try decode(data, response: response)
    }

    /// Sends a JSON request without a body.
    private func sendJSON<Response: Decodable>(
        method: String,
        path: String,
        requiresAuth: Bool
    ) async throws -> Response {
        let request = try makeRequest(
            method: method,
            path: path,
            requiresAuth: requiresAuth
        )

        let (data, response) = try await urlSession.data(for: request)

        return try decode(data, response: response)
    }

    /// Builds a URL request and attaches the bearer token when required.
    private func makeRequest(
        method: String,
        path: String,
        requiresAuth: Bool
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: configuration.baseURL)?.absoluteURL else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth {
            guard let authToken else {
                throw APIClientError.missingAuthToken
            }

            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    /// Decodes a JSON API response or converts an API error response to Swift error.
    private func decode<Response: Decodable>(_ data: Data, response: URLResponse) throws -> Response {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw APIClientError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message ?? "The server returned status \(httpResponse.statusCode)."
            )
        }

        return try decoder.decode(Response.self, from: data)
    }

    /// Validates a binary response such as image download.
    private func validateBinaryResponse(_ data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw APIClientError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message ?? "The server returned status \(httpResponse.statusCode)."
            )
        }
    }
}

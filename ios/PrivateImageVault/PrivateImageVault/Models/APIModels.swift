import Foundation

/// Public user profile returned by the backend.
///
/// This intentionally contains no password data and no private device keys.
struct APIUser: Codable, Identifiable, Hashable {
    /// Server-generated user id.
    let id: String

    /// Human-readable username used for search and sending.
    let username: String

    /// ISO-8601 string created by the backend.
    let createdAt: String?
}

/// Local authenticated session.
///
/// The token is stored in Keychain by `SessionStore`; views should not persist it.
struct AuthSession: Codable, Equatable {
    /// Bearer token sent in the Authorization header.
    let token: String

    /// Public profile for the logged-in user.
    let user: APIUser
}

/// Response returned by register and login endpoints.
struct AuthResponse: Codable {
    /// Bearer token created by the backend.
    let token: String

    /// Public profile for the authenticated user.
    let user: APIUser

    /// Converts the API response into the local session model.
    var session: AuthSession {
        AuthSession(token: token, user: user)
    }
}

/// Request body used by register and login.
struct AuthRequest: Encodable {
    /// Username typed by the user.
    let username: String

    /// Password typed by the user.
    let password: String
}

/// Response returned by `/v1/auth/me`.
struct MeResponse: Codable {
    /// Public profile for the current token.
    let user: APIUser
}

/// Response returned by `/v1/users/search`.
struct UserSearchResponse: Codable {
    /// Matching public user profiles.
    let users: [APIUser]
}

/// Metadata for one object stored by the backend.
///
/// In this plaintext milestone the object is an image. Later the same model can
/// describe encrypted bytes without changing the delivery endpoints.
struct APIObject: Codable, Identifiable, Hashable {
    /// Server-generated object id.
    let id: String

    /// User id that uploaded the object.
    let ownerUserId: String

    /// MIME type sent at upload time.
    let contentType: String

    /// Number of bytes stored by the object service.
    let byteSize: Int

    /// SHA-256 digest returned for integrity/debug checks.
    let sha256Hash: String

    /// ISO-8601 creation date string.
    let createdAt: String
}

/// Response returned by `POST /v1/objects`.
struct ObjectUploadResponse: Codable {
    /// Metadata for the uploaded object.
    let object: APIObject
}

/// Request body for creating an image message.
struct CreateImageMessageRequest: Encodable {
    /// Server id of the recipient user.
    let recipientUserId: String

    /// Server id of the already-uploaded image object.
    let objectId: String
}

/// Image delivery record returned by message endpoints.
struct ImageMessage: Codable, Identifiable, Hashable {
    /// Server-generated message id.
    let id: String

    /// User id that sent the image.
    let senderUserId: String

    /// User id that should receive the image.
    let recipientUserId: String

    /// Object id that contains the image bytes.
    let objectId: String

    /// ISO-8601 creation date string.
    let createdAt: String

    /// ISO-8601 delivery date string, if marked delivered.
    let deliveredAt: String?

    /// ISO-8601 seen date string, if marked seen.
    let seenAt: String?

    /// Public sender profile included for display.
    let sender: APIUser?

    /// Public recipient profile included for display.
    let recipient: APIUser?

    /// Object metadata included for download/display.
    let object: APIObject?
}

/// Response returned by single-message endpoints.
struct ImageMessageResponse: Codable {
    /// The created or updated image message.
    let message: ImageMessage
}

/// Response returned by inbox and sent-message endpoints.
struct ImageMessagesResponse: Codable {
    /// Messages in newest-first order.
    let messages: [ImageMessage]
}

/// Small success response returned by logout.
struct APIStatusResponse: Codable {
    /// Whether the operation succeeded.
    let ok: Bool
}

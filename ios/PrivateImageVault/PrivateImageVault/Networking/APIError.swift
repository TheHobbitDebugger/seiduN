import Foundation

/// Error response shape returned by the Node.js API.
struct APIErrorEnvelope: Decodable {
    /// The nested error object.
    let error: APIErrorBody
}

/// Inner error object returned by the Node.js API.
struct APIErrorBody: Decodable {
    /// Stable machine-readable code.
    let code: String

    /// Human-readable message safe to show during development.
    let message: String
}

/// Errors produced by the iOS API client.
enum APIClientError: LocalizedError {
    /// The configured URL or route path could not form a valid URL.
    case invalidURL

    /// A protected endpoint was called before login.
    case missingAuthToken

    /// The response was not an HTTP response.
    case invalidResponse

    /// The backend returned a non-2xx status.
    case requestFailed(statusCode: Int, message: String)

    /// A local validation error, such as an empty recipient username.
    case localMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is not valid."
        case .missingAuthToken:
            return "You need to log in first."
        case .invalidResponse:
            return "The server response was not valid."
        case .requestFailed(_, let message):
            return message
        case .localMessage(let message):
            return message
        }
    }
}

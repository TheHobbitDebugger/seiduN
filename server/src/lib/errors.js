/// Error type used when a route needs to return a specific HTTP status.
///
/// Throwing this from services keeps route code readable while still returning a
/// predictable JSON error body to iOS.
class HttpError extends Error {
  constructor(statusCode, code, message) {
    super(message);
    this.name = "HttpError";
    this.statusCode = statusCode;
    this.code = code;
  }
}

module.exports = {
  HttpError
};

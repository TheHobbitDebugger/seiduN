const { HttpError } = require("../lib/errors");
const { getBearerToken } = require("../lib/http");
const { hashSessionToken } = require("../lib/security");

/// Loads the authenticated user for a request.
///
/// Every protected endpoint calls this helper so bearer-token validation behaves
/// consistently across users, objects, and image messages.
async function requireAuth(req, db) {
  const token = getBearerToken(req);

  if (!token) {
    throw new HttpError(401, "missing_token", "A bearer token is required.");
  }

  const tokenHash = hashSessionToken(token);
  const now = new Date();

  return db.read((data) => {
    const session = data.sessions.find((candidate) => candidate.tokenHash === tokenHash);

    if (!session) {
      throw new HttpError(401, "invalid_token", "The bearer token is not valid.");
    }

    if (new Date(session.expiresAt) <= now) {
      throw new HttpError(401, "expired_token", "The bearer token has expired.");
    }

    const user = data.users.find((candidate) => candidate.id === session.userId);

    if (!user) {
      throw new HttpError(401, "invalid_session", "The session user no longer exists.");
    }

    return {
      user,
      session,
      tokenHash
    };
  });
}

module.exports = {
  requireAuth
};

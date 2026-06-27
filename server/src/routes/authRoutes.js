const { HttpError } = require("../lib/errors");
const { readJsonBody, sendJson } = require("../lib/http");
const {
  createId,
  createSessionToken,
  hashPassword,
  hashSessionToken,
  verifyPassword
} = require("../lib/security");
const { publicUser } = require("../lib/serializers");
const { requireAuth } = require("../services/authContext");

/// Username rule for the first account system.
///
/// Lowercase letters, numbers, and underscores keep search and URLs simple.
const USERNAME_PATTERN = /^[a-z0-9_]{3,24}$/;

/// Password minimum used by the plaintext MVP.
const MIN_PASSWORD_LENGTH = 8;

/// Routes under `/v1/auth`.
async function handleAuthRoute(req, res, url, services) {
  if (req.method === "POST" && url.pathname === "/v1/auth/register") {
    return register(req, res, services);
  }

  if (req.method === "POST" && url.pathname === "/v1/auth/login") {
    return login(req, res, services);
  }

  if (req.method === "POST" && url.pathname === "/v1/auth/logout") {
    return logout(req, res, services);
  }

  if (req.method === "GET" && url.pathname === "/v1/auth/me") {
    return me(req, res, services);
  }

  return false;
}

/// Creates a new account and immediately returns a session token.
async function register(req, res, services) {
  const body = await readJsonBody(req);
  const username = normalizeUsername(body.username);
  const password = String(body.password || "");

  validateUsername(username);
  validatePassword(password);

  const passwordFields = await hashPassword(password);
  const token = createSessionToken();
  const tokenHash = hashSessionToken(token);
  const now = new Date();

  const user = await services.db.mutate((data) => {
    if (data.users.some((candidate) => candidate.usernameNormalized === username)) {
      throw new HttpError(409, "username_taken", "That username is already taken.");
    }

    const newUser = {
      id: createId(),
      username,
      usernameNormalized: username,
      passwordSalt: passwordFields.passwordSalt,
      passwordHash: passwordFields.passwordHash,
      createdAt: now.toISOString()
    };

    data.users.push(newUser);
    data.sessions.push(makeSession(newUser.id, tokenHash, now));

    return newUser;
  });

  sendJson(res, 201, {
    token,
    user: publicUser(user)
  });

  return true;
}

/// Verifies a username/password pair and returns a new session token.
async function login(req, res, services) {
  const body = await readJsonBody(req);
  const username = normalizeUsername(body.username);
  const password = String(body.password || "");

  const user = await services.db.read((data) =>
    data.users.find((candidate) => candidate.usernameNormalized === username)
  );

  if (!user || !(await verifyPassword(password, user))) {
    throw new HttpError(401, "invalid_credentials", "The username or password is incorrect.");
  }

  const token = createSessionToken();
  const tokenHash = hashSessionToken(token);
  const now = new Date();

  await services.db.mutate((data) => {
    data.sessions.push(makeSession(user.id, tokenHash, now));
  });

  sendJson(res, 200, {
    token,
    user: publicUser(user)
  });

  return true;
}

/// Deletes the current session token.
async function logout(req, res, services) {
  const auth = await requireAuth(req, services.db);

  await services.db.mutate((data) => {
    data.sessions = data.sessions.filter((session) => session.tokenHash !== auth.tokenHash);
  });

  sendJson(res, 200, {
    ok: true
  });

  return true;
}

/// Returns the authenticated user's public profile.
async function me(req, res, services) {
  const auth = await requireAuth(req, services.db);

  sendJson(res, 200, {
    user: publicUser(auth.user)
  });

  return true;
}

/// Creates a server-side session record.
function makeSession(userId, tokenHash, now) {
  const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

  return {
    id: createId(),
    userId,
    tokenHash,
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString()
  };
}

/// Normalizes user input before validation and search.
function normalizeUsername(username) {
  return String(username || "").trim().toLowerCase();
}

/// Ensures a username is simple enough for the first account system.
function validateUsername(username) {
  if (!USERNAME_PATTERN.test(username)) {
    throw new HttpError(
      400,
      "invalid_username",
      "Usernames must be 3-24 characters using lowercase letters, numbers, or underscores."
    );
  }
}

/// Ensures the password is not empty or trivially short.
function validatePassword(password) {
  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new HttpError(400, "weak_password", "Passwords must be at least 8 characters.");
  }
}

module.exports = {
  handleAuthRoute
};

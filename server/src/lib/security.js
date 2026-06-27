const crypto = require("node:crypto");
const { promisify } = require("node:util");

/// Promise-based wrapper around Node's built-in scrypt implementation.
const scrypt = promisify(crypto.scrypt);

/// Number of bytes produced by the password hashing function.
const PASSWORD_HASH_BYTES = 64;

/// Creates a salted password hash for storage.
///
/// This is still an MVP auth system, but passwords are never stored in plaintext.
async function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString("hex");
  const derivedKey = await scrypt(password, salt, PASSWORD_HASH_BYTES);

  return {
    passwordSalt: salt,
    passwordHash: derivedKey.toString("hex")
  };
}

/// Checks a password against the stored salt and hash.
///
/// `timingSafeEqual` avoids leaking partial hash comparisons through timing.
async function verifyPassword(password, user) {
  const derivedKey = await scrypt(password, user.passwordSalt, PASSWORD_HASH_BYTES);
  const expected = Buffer.from(user.passwordHash, "hex");

  if (derivedKey.length !== expected.length) {
    return false;
  }

  return crypto.timingSafeEqual(derivedKey, expected);
}

/// Creates a random bearer token to return to the client.
function createSessionToken() {
  return crypto.randomBytes(32).toString("base64url");
}

/// Hashes a session token before storing it in the JSON database.
///
/// If the metadata database leaks during development, raw session tokens are not
/// immediately exposed.
function hashSessionToken(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

/// Creates a URL-safe random id.
///
/// `crypto.randomUUID` is readable, globally unique for this MVP, and fine for
/// object/message/user identifiers.
function createId() {
  return crypto.randomUUID();
}

/// Creates the SHA-256 digest of uploaded object bytes.
function sha256Hex(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

module.exports = {
  hashPassword,
  verifyPassword,
  createSessionToken,
  hashSessionToken,
  createId,
  sha256Hex
};

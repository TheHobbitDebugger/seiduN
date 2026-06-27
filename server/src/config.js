const path = require("node:path");

/// Absolute path to the backend folder.
///
/// All default runtime paths are derived from this directory so the backend does
/// not write metadata or uploaded image bytes outside the project by accident.
const SERVER_ROOT = path.resolve(__dirname, "..");

/// Central configuration for the development API.
///
/// Environment variables are supported so tests can point the server at isolated
/// temporary folders without changing source code.
const config = {
  /// The local port used when running `npm start`.
  port: Number(process.env.PORT || 3000),

  /// The host is loopback-only by default for development safety.
  host: process.env.HOST || "127.0.0.1",

  /// JSON metadata database path.
  dbFilePath: process.env.PRIVATE_VAULT_DB_PATH || path.join(SERVER_ROOT, "data", "db.json"),

  /// Root folder where raw uploaded object bytes are stored.
  objectStorageRoot:
    process.env.PRIVATE_VAULT_OBJECT_ROOT || path.join(SERVER_ROOT, "storage", "objects"),

  /// Maximum accepted upload size for the plaintext image MVP.
  maxObjectBytes: Number(process.env.PRIVATE_VAULT_MAX_OBJECT_BYTES || 12 * 1024 * 1024)
};

module.exports = {
  config,
  SERVER_ROOT
};

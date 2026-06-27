const fs = require("node:fs/promises");
const path = require("node:path");

/// Creates the empty database shape used by the plaintext MVP.
function emptyDatabase() {
  return {
    users: [],
    sessions: [],
    objects: [],
    imageMessages: []
  };
}

/// Tiny JSON-file metadata database.
///
/// This is intentionally not a production database. It gives us persistent local
/// state while the account/session/object API is still small enough to inspect.
class JsonDatabase {
  constructor(filePath) {
    /// Absolute path to the JSON metadata file.
    this.filePath = filePath;

    /// In-memory database object loaded from disk on first use.
    this.data = emptyDatabase();

    /// Tracks whether the database has already been loaded.
    this.isLoaded = false;

    /// Serializes writes so concurrent requests do not write partial JSON over
    /// each other.
    this.writeQueue = Promise.resolve();
  }

  /// Loads metadata from disk, creating the database file if it does not exist.
  async load() {
    if (this.isLoaded) {
      return;
    }

    await fs.mkdir(path.dirname(this.filePath), { recursive: true });

    try {
      const raw = await fs.readFile(this.filePath, "utf8");
      this.data = {
        ...emptyDatabase(),
        ...JSON.parse(raw)
      };
    } catch (error) {
      if (error.code !== "ENOENT") {
        throw error;
      }

      this.data = emptyDatabase();
      await this.save();
    }

    this.isLoaded = true;
  }

  /// Reads the current database state through a callback.
  ///
  /// The callback must not mutate `data`; route code uses `mutate` for writes.
  async read(callback) {
    await this.load();
    return callback(this.data);
  }

  /// Mutates the database and persists the result to disk.
  ///
  /// The callback is synchronous on purpose, which keeps mutation ordering simple.
  async mutate(callback) {
    await this.load();
    const result = callback(this.data);
    await this.save();
    return result;
  }

  /// Persists the in-memory database object using an atomic replace.
  async save() {
    this.writeQueue = this.writeQueue.then(async () => {
      await fs.mkdir(path.dirname(this.filePath), { recursive: true });

      const temporaryPath = `${this.filePath}.tmp`;
      const encoded = JSON.stringify(this.data, null, 2);

      await fs.writeFile(temporaryPath, encoded);
      await fs.rename(temporaryPath, this.filePath);
    });

    return this.writeQueue;
  }
}

module.exports = {
  JsonDatabase
};

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");

/// Filesystem-backed object storage controlled by this project.
///
/// It stores opaque bytes under a private server directory. In the plaintext MVP
/// those bytes are images; later they will be encrypted blobs.
class ObjectStorage {
  constructor(rootDirectory) {
    /// Absolute storage root. All object paths are checked against this folder.
    this.rootDirectory = path.resolve(rootDirectory);
  }

  /// Saves object bytes and returns the relative path recorded in metadata.
  async saveObjectBytes(objectId, buffer) {
    const relativePath = this.relativePathForObject(objectId);
    const absolutePath = this.absolutePathFor(relativePath);
    const temporaryPath = `${absolutePath}.tmp`;

    await fsp.mkdir(path.dirname(absolutePath), { recursive: true });

    /// Write-then-rename prevents partially written objects from appearing at the
    /// final path if the process stops mid-write.
    await fsp.writeFile(temporaryPath, buffer);
    await fsp.rename(temporaryPath, absolutePath);

    return relativePath;
  }

  /// Returns a readable stream for an object file.
  createReadStream(relativePath) {
    return fs.createReadStream(this.absolutePathFor(relativePath));
  }

  /// Reads file metadata for response headers.
  async stat(relativePath) {
    return fsp.stat(this.absolutePathFor(relativePath));
  }

  /// Builds a sharded relative path from an object id.
  ///
  /// Sharding avoids putting every file in one directory as the object count grows.
  relativePathForObject(objectId) {
    const cleanId = objectId.replace(/[^a-zA-Z0-9-]/g, "");
    const firstShard = cleanId.slice(0, 2) || "00";
    const secondShard = cleanId.slice(2, 4) || "00";

    return path.join(firstShard, secondShard, `${cleanId}.bin`);
  }

  /// Resolves a relative object path and verifies it stays under the storage root.
  absolutePathFor(relativePath) {
    const absolutePath = path.resolve(this.rootDirectory, relativePath);
    const rootWithSeparator = `${this.rootDirectory}${path.sep}`;

    if (absolutePath !== this.rootDirectory && !absolutePath.startsWith(rootWithSeparator)) {
      throw new Error("Object path escaped the storage root.");
    }

    return absolutePath;
  }
}

module.exports = {
  ObjectStorage
};

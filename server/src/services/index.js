const { config } = require("../config");
const { JsonDatabase } = require("../storage/jsonDatabase");
const { ObjectStorage } = require("../storage/objectStorage");

/// Creates shared service instances for the HTTP app.
///
/// Tests pass custom paths here so they can run without touching normal local
/// development data.
function createServices(options = {}) {
  const db = new JsonDatabase(options.dbFilePath || config.dbFilePath);
  const objectStorage = new ObjectStorage(options.objectStorageRoot || config.objectStorageRoot);

  return {
    db,
    objectStorage,
    maxObjectBytes: options.maxObjectBytes || config.maxObjectBytes
  };
}

module.exports = {
  createServices
};

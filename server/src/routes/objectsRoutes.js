const { HttpError } = require("../lib/errors");
const { collectRequestBody, sendJson } = require("../lib/http");
const { createId, sha256Hex } = require("../lib/security");
const { publicObject } = require("../lib/serializers");
const { requireAuth } = require("../services/authContext");

/// Image content types accepted by the plaintext upload endpoint.
const ALLOWED_OBJECT_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/heic",
  "application/octet-stream"
]);

/// Routes under `/v1/objects`.
async function handleObjectsRoute(req, res, url, services) {
  if (req.method === "POST" && url.pathname === "/v1/objects") {
    return uploadObject(req, res, services);
  }

  const objectMatch = url.pathname.match(/^\/v1\/objects\/([^/]+)$/);

  if (req.method === "GET" && objectMatch) {
    return downloadObject(req, res, objectMatch[1], services);
  }

  return false;
}

/// Stores raw image bytes in the self-owned filesystem object store.
async function uploadObject(req, res, services) {
  const auth = await requireAuth(req, services.db);
  const contentType = normalizeContentType(req.headers["content-type"]);

  if (!ALLOWED_OBJECT_TYPES.has(contentType)) {
    throw new HttpError(415, "unsupported_media_type", "Upload an image/jpeg, image/png, or image/heic object.");
  }

  const body = await collectRequestBody(req, {
    maxBytes: services.maxObjectBytes
  });

  if (body.length === 0) {
    throw new HttpError(400, "empty_object", "The uploaded object cannot be empty.");
  }

  const objectId = createId();
  const relativePath = await services.objectStorage.saveObjectBytes(objectId, body);
  const now = new Date();

  const object = {
    id: objectId,
    ownerUserId: auth.user.id,
    contentType,
    byteSize: body.length,
    sha256Hash: sha256Hex(body),
    relativePath,
    createdAt: now.toISOString()
  };

  await services.db.mutate((data) => {
    data.objects.push(object);
  });

  sendJson(res, 201, {
    object: publicObject(object)
  });

  return true;
}

/// Streams raw image bytes back to an authorized owner, sender, or recipient.
async function downloadObject(req, res, objectId, services) {
  const auth = await requireAuth(req, services.db);

  const object = await services.db.read((data) => {
    const storedObject = data.objects.find((candidate) => candidate.id === objectId);

    if (!storedObject) {
      throw new HttpError(404, "object_not_found", "The object does not exist.");
    }

    const hasMessageAccess = data.imageMessages.some(
      (message) =>
        message.objectId === storedObject.id &&
        (message.senderUserId === auth.user.id || message.recipientUserId === auth.user.id)
    );

    if (storedObject.ownerUserId !== auth.user.id && !hasMessageAccess) {
      throw new HttpError(403, "object_forbidden", "You do not have access to this object.");
    }

    return storedObject;
  });

  const fileStat = await services.objectStorage.stat(object.relativePath);

  res.writeHead(200, {
    "Content-Type": object.contentType,
    "Content-Length": fileStat.size,
    "Cache-Control": "no-store",
    "X-Object-Id": object.id,
    "X-Object-Sha256": object.sha256Hash
  });

  const stream = services.objectStorage.createReadStream(object.relativePath);

  stream.on("error", () => {
    res.destroy();
  });

  stream.pipe(res);

  return true;
}

/// Removes optional charset parameters from a content type header.
function normalizeContentType(contentType) {
  return String(contentType || "application/octet-stream")
    .split(";")[0]
    .trim()
    .toLowerCase();
}

module.exports = {
  handleObjectsRoute
};

const { HttpError } = require("./errors");

/// Reads a request body into memory with a strict byte limit.
///
/// The MVP keeps this simple because iPhone image uploads are small enough for a
/// first prototype. A production object store should stream uploads to disk.
function collectRequestBody(req, options = {}) {
  const maxBytes = options.maxBytes || 1024 * 1024;

  return new Promise((resolve, reject) => {
    const chunks = [];
    let totalBytes = 0;

    req.on("data", (chunk) => {
      totalBytes += chunk.length;

      if (totalBytes > maxBytes) {
        reject(new HttpError(413, "payload_too_large", "The request body is too large."));
        req.destroy();
        return;
      }

      chunks.push(chunk);
    });

    req.on("end", () => {
      resolve(Buffer.concat(chunks));
    });

    req.on("error", (error) => {
      reject(error);
    });
  });
}

/// Reads and parses a JSON request body.
///
/// Routes use this for account/session/message metadata. Raw object uploads use
/// `collectRequestBody` directly so image bytes are not treated as JSON.
async function readJsonBody(req, options = {}) {
  const body = await collectRequestBody(req, {
    maxBytes: options.maxBytes || 1024 * 1024
  });

  if (body.length === 0) {
    return {};
  }

  try {
    return JSON.parse(body.toString("utf8"));
  } catch {
    throw new HttpError(400, "invalid_json", "The request body must be valid JSON.");
  }
}

/// Sends a JSON response with security-conscious cache defaults.
function sendJson(res, statusCode, payload) {
  const encoded = Buffer.from(JSON.stringify(payload));

  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": encoded.length,
    "Cache-Control": "no-store"
  });

  res.end(encoded);
}

/// Sends a standard JSON error response.
function sendError(res, statusCode, code, message) {
  sendJson(res, statusCode, {
    error: {
      code,
      message
    }
  });
}

/// Extracts the bearer token from the Authorization header.
function getBearerToken(req) {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");

  if (scheme !== "Bearer" || !token) {
    return null;
  }

  return token;
}

module.exports = {
  collectRequestBody,
  readJsonBody,
  sendJson,
  sendError,
  getBearerToken
};

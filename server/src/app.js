const { HttpError } = require("./lib/errors");
const { sendError } = require("./lib/http");
const { routeRequest } = require("./routes");

/// Creates the HTTP request handler.
///
/// The handler is framework-free so every request path is explicit and easy to
/// inspect while the protocol is still being designed.
function createApp(services) {
  return async function app(req, res) {
    applyCommonHeaders(res);

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    try {
      const wasHandled = await routeRequest(req, res, services);

      if (!wasHandled && !res.headersSent) {
        sendError(res, 404, "not_found", "The requested endpoint does not exist.");
      }
    } catch (error) {
      handleRouteError(res, error);
    }
  };
}

/// Adds headers that are useful for native development and safe JSON APIs.
function applyCommonHeaders(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Authorization,Content-Type");
  res.setHeader("X-Content-Type-Options", "nosniff");
}

/// Converts thrown route errors into API responses.
function handleRouteError(res, error) {
  if (res.headersSent) {
    res.destroy();
    return;
  }

  if (error instanceof HttpError) {
    sendError(res, error.statusCode, error.code, error.message);
    return;
  }

  console.error(error);
  sendError(res, 500, "internal_error", "An internal server error occurred.");
}

module.exports = {
  createApp
};

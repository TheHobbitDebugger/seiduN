const { sendJson } = require("../lib/http");
const { handleAuthRoute } = require("./authRoutes");
const { handleUsersRoute } = require("./usersRoutes");
const { handleObjectsRoute } = require("./objectsRoutes");
const { handleImageMessagesRoute } = require("./imageMessagesRoutes");

/// Dispatches one HTTP request to the matching route module.
async function routeRequest(req, res, services) {
  const url = new URL(req.url, "http://127.0.0.1");

  if (req.method === "GET" && url.pathname === "/health") {
    sendJson(res, 200, {
      ok: true
    });
    return true;
  }

  if (url.pathname.startsWith("/v1/auth")) {
    return handleAuthRoute(req, res, url, services);
  }

  if (url.pathname.startsWith("/v1/users")) {
    return handleUsersRoute(req, res, url, services);
  }

  if (url.pathname.startsWith("/v1/objects")) {
    return handleObjectsRoute(req, res, url, services);
  }

  if (url.pathname.startsWith("/v1/image-messages")) {
    return handleImageMessagesRoute(req, res, url, services);
  }

  return false;
}

module.exports = {
  routeRequest
};

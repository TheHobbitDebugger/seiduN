const { HttpError } = require("../lib/errors");
const { sendJson } = require("../lib/http");
const { publicUser } = require("../lib/serializers");
const { requireAuth } = require("../services/authContext");

/// Routes under `/v1/users`.
async function handleUsersRoute(req, res, url, services) {
  if (req.method === "GET" && url.pathname === "/v1/users/search") {
    return searchUsers(req, res, url, services);
  }

  return false;
}

/// Searches users by username prefix.
///
/// Authentication is required so the public user directory is not anonymous.
async function searchUsers(req, res, url, services) {
  await requireAuth(req, services.db);

  const query = String(url.searchParams.get("username") || "").trim().toLowerCase();

  if (query.length < 1) {
    throw new HttpError(400, "missing_query", "The username query is required.");
  }

  const users = await services.db.read((data) =>
    data.users
      .filter((user) => user.usernameNormalized.startsWith(query))
      .slice(0, 20)
      .map(publicUser)
  );

  sendJson(res, 200, {
    users
  });

  return true;
}

module.exports = {
  handleUsersRoute
};

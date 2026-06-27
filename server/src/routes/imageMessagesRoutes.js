const { HttpError } = require("../lib/errors");
const { readJsonBody, sendJson } = require("../lib/http");
const { createId } = require("../lib/security");
const { publicImageMessage } = require("../lib/serializers");
const { requireAuth } = require("../services/authContext");

/// Routes under `/v1/image-messages`.
async function handleImageMessagesRoute(req, res, url, services) {
  if (req.method === "POST" && url.pathname === "/v1/image-messages") {
    return createImageMessage(req, res, services);
  }

  if (req.method === "GET" && url.pathname === "/v1/image-messages/inbox") {
    return listInbox(req, res, services);
  }

  if (req.method === "GET" && url.pathname === "/v1/image-messages/sent") {
    return listSent(req, res, services);
  }

  const statusMatch = url.pathname.match(/^\/v1\/image-messages\/([^/]+)\/(delivered|seen)$/);

  if (req.method === "POST" && statusMatch) {
    return updateMessageStatus(req, res, statusMatch[1], statusMatch[2], services);
  }

  const messageMatch = url.pathname.match(/^\/v1\/image-messages\/([^/]+)$/);

  if (req.method === "GET" && messageMatch) {
    return getImageMessage(req, res, messageMatch[1], services);
  }

  return false;
}

/// Creates a delivery record pointing at an already-uploaded object.
async function createImageMessage(req, res, services) {
  const auth = await requireAuth(req, services.db);
  const body = await readJsonBody(req);
  const recipientUserId = String(body.recipientUserId || "");
  const objectId = String(body.objectId || "");
  const now = new Date();

  const message = await services.db.mutate((data) => {
    const recipient = data.users.find((user) => user.id === recipientUserId);

    if (!recipient) {
      throw new HttpError(404, "recipient_not_found", "The recipient user does not exist.");
    }

    if (recipient.id === auth.user.id) {
      throw new HttpError(400, "cannot_send_to_self", "Choose another user as the recipient.");
    }

    const object = data.objects.find((candidate) => candidate.id === objectId);

    if (!object) {
      throw new HttpError(404, "object_not_found", "The object does not exist.");
    }

    if (object.ownerUserId !== auth.user.id) {
      throw new HttpError(403, "object_not_owned", "You can only send objects that you uploaded.");
    }

    const newMessage = {
      id: createId(),
      senderUserId: auth.user.id,
      recipientUserId: recipient.id,
      objectId: object.id,
      createdAt: now.toISOString(),
      deliveredAt: null,
      seenAt: null
    };

    data.imageMessages.push(newMessage);

    return publicImageMessage(newMessage, data);
  });

  sendJson(res, 201, {
    message
  });

  return true;
}

/// Lists image messages received by the authenticated user.
async function listInbox(req, res, services) {
  const auth = await requireAuth(req, services.db);

  const messages = await services.db.read((data) =>
    data.imageMessages
      .filter((message) => message.recipientUserId === auth.user.id)
      .sort((left, right) => new Date(right.createdAt) - new Date(left.createdAt))
      .map((message) => publicImageMessage(message, data))
  );

  sendJson(res, 200, {
    messages
  });

  return true;
}

/// Lists image messages sent by the authenticated user.
async function listSent(req, res, services) {
  const auth = await requireAuth(req, services.db);

  const messages = await services.db.read((data) =>
    data.imageMessages
      .filter((message) => message.senderUserId === auth.user.id)
      .sort((left, right) => new Date(right.createdAt) - new Date(left.createdAt))
      .map((message) => publicImageMessage(message, data))
  );

  sendJson(res, 200, {
    messages
  });

  return true;
}

/// Returns one image message if the authenticated user is involved in it.
async function getImageMessage(req, res, messageId, services) {
  const auth = await requireAuth(req, services.db);

  const message = await services.db.read((data) => {
    const storedMessage = data.imageMessages.find((candidate) => candidate.id === messageId);

    if (!storedMessage) {
      throw new HttpError(404, "message_not_found", "The image message does not exist.");
    }

    if (storedMessage.senderUserId !== auth.user.id && storedMessage.recipientUserId !== auth.user.id) {
      throw new HttpError(403, "message_forbidden", "You do not have access to this image message.");
    }

    return publicImageMessage(storedMessage, data);
  });

  sendJson(res, 200, {
    message
  });

  return true;
}

/// Marks a message delivered or seen.
///
/// Only the recipient can set these states because delivery/seen status describes
/// recipient-side behavior.
async function updateMessageStatus(req, res, messageId, status, services) {
  const auth = await requireAuth(req, services.db);
  const now = new Date().toISOString();

  const message = await services.db.mutate((data) => {
    const storedMessage = data.imageMessages.find((candidate) => candidate.id === messageId);

    if (!storedMessage) {
      throw new HttpError(404, "message_not_found", "The image message does not exist.");
    }

    if (storedMessage.recipientUserId !== auth.user.id) {
      throw new HttpError(403, "message_status_forbidden", "Only the recipient can update message status.");
    }

    if (status === "delivered" && !storedMessage.deliveredAt) {
      storedMessage.deliveredAt = now;
    }

    if (status === "seen") {
      if (!storedMessage.deliveredAt) {
        storedMessage.deliveredAt = now;
      }

      if (!storedMessage.seenAt) {
        storedMessage.seenAt = now;
      }
    }

    return publicImageMessage(storedMessage, data);
  });

  sendJson(res, 200, {
    message
  });

  return true;
}

module.exports = {
  handleImageMessagesRoute
};

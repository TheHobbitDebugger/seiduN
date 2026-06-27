/// Returns the public user shape sent to clients.
///
/// Password salts, password hashes, and other private server-side fields are not
/// included in API responses.
function publicUser(user) {
  return {
    id: user.id,
    username: user.username,
    createdAt: user.createdAt
  };
}

/// Returns object metadata that is useful to clients.
///
/// The physical storage path is deliberately omitted so clients cannot learn or
/// depend on the server's internal filesystem layout.
function publicObject(object) {
  return {
    id: object.id,
    ownerUserId: object.ownerUserId,
    contentType: object.contentType,
    byteSize: object.byteSize,
    sha256Hash: object.sha256Hash,
    createdAt: object.createdAt
  };
}

/// Returns the API shape for one image message.
function publicImageMessage(message, data) {
  const sender = data.users.find((user) => user.id === message.senderUserId);
  const recipient = data.users.find((user) => user.id === message.recipientUserId);
  const object = data.objects.find((storedObject) => storedObject.id === message.objectId);

  return {
    id: message.id,
    senderUserId: message.senderUserId,
    recipientUserId: message.recipientUserId,
    objectId: message.objectId,
    createdAt: message.createdAt,
    deliveredAt: message.deliveredAt,
    seenAt: message.seenAt,
    sender: sender ? publicUser(sender) : null,
    recipient: recipient ? publicUser(recipient) : null,
    object: object ? publicObject(object) : null
  };
}

module.exports = {
  publicUser,
  publicObject,
  publicImageMessage
};

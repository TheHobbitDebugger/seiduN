# PrivateImageVault API

This is the plaintext backend for the first delivery milestone.

It deliberately uses only Node.js standard-library modules so the first version
is easy to inspect and does not hide behavior behind framework defaults.

## What It Does

- Creates users with usernames and passwords.
- Hashes passwords with Node's built-in `crypto.scrypt`.
- Creates bearer-token sessions.
- Stores metadata in a local JSON database.
- Stores uploaded image bytes in a local filesystem object store.
- Lets users send an uploaded image object to another user.
- Lets recipients list inbox messages and download the raw image bytes.

## What It Does Not Do Yet

- It does not encrypt images.
- It does not use a production database.
- It does not implement push notifications.
- It does not use HTTPS by itself; put it behind HTTPS in real deployments.

## Local Run

```sh
cd server
npm start
```

The API listens on `http://127.0.0.1:3000` by default.

## Smoke Test

```sh
cd server
npm run smoke
```

The smoke test creates two users, uploads fake image bytes, sends an image
message, downloads the object as the recipient, and marks the message seen.

## API Summary

```http
POST /v1/auth/register
POST /v1/auth/login
POST /v1/auth/logout
GET  /v1/auth/me

GET  /v1/users/search?username=alice

POST /v1/objects
GET  /v1/objects/:objectId

POST /v1/image-messages
GET  /v1/image-messages/inbox
GET  /v1/image-messages/sent
GET  /v1/image-messages/:messageId
POST /v1/image-messages/:messageId/delivered
POST /v1/image-messages/:messageId/seen
```

For now, `POST /v1/objects` receives raw image bytes with `Content-Type:
image/jpeg`, `image/png`, `image/heic`, or `application/octet-stream`.

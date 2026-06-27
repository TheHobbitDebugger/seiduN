# PrivateImageVault

PrivateImageVault is being built in small, auditable milestones.

The current milestone is:

```text
Native iOS app -> plaintext Node.js API -> self-owned filesystem object storage
```

No encryption is implemented yet. That is intentional: this stage proves account
creation, session handling, private image capture, object upload, image delivery,
and inbox download before cryptography is added.

## Folders

```text
ios/PrivateImageVault   Native SwiftUI iPhone app
server                  Node.js plaintext API and object storage
```

## Backend

The backend has no third-party package dependencies yet. It uses Node.js built-in
modules for HTTP, password hashing, token creation, JSON metadata, and local file
storage.

```sh
cd server
npm start
```

Smoke test:

```sh
cd server
npm run smoke
```

## iOS

The iOS app:

- Opens the camera.
- Saves captured images only in the app sandbox.
- Does not call `UIImageWriteToSavedPhotosAlbum`.
- Does not request Photos library permission.
- Stores the API session in Keychain.
- Uploads selected private images to the plaintext API.
- Downloads received images back into the app-private gallery.

On a Mac with XcodeGen:

```sh
cd ios/PrivateImageVault
xcodegen generate
open PrivateImageVault.xcodeproj
```

## Plaintext First, Encryption Later

The current API stores raw image bytes so delivery can be verified with no
cryptography involved. Once this works, the iOS app can encrypt bytes locally
before `POST /v1/objects`, and the backend object store will not need to know
whether the bytes are plaintext or ciphertext.

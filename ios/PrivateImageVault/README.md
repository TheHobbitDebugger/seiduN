# PrivateImageVault

PrivateImageVault is the first native iOS slice of the image-only messenger.
This version does not send images to a server yet. It only proves the local rule:
an image can be captured with the camera and saved inside the app sandbox instead
of the standard iOS Photos gallery.

## Current Scope

- Native iOS app written in Swift and SwiftUI.
- Camera capture through `UIImagePickerController`.
- Local image storage in the app's Documents directory.
- Account registration and login through the local Node.js API.
- Session token persistence in Keychain.
- Plaintext upload of app-private images to the Node.js object API.
- Inbox download that saves received images back into the app-private gallery.
- No call to `UIImageWriteToSavedPhotosAlbum`.
- No Photos library permission.
- No encryption yet.

## Why Documents Storage

The app writes images to:

```text
<App Sandbox>/Documents/PrivateCaptures/
```

This is private to the app sandbox and is not the user's Photos gallery. The
files are also written with complete file protection so iOS keeps them encrypted
while the device is locked.

## Project Generation

This folder includes a `project.yml` file for XcodeGen so the project structure
stays readable and source-controlled.

On a Mac with Xcode installed:

```sh
cd ios/PrivateImageVault
xcodegen generate
open PrivateImageVault.xcodeproj
```

If you do not want to use XcodeGen, create a new SwiftUI iOS app in Xcode named
`PrivateImageVault`, then copy the `PrivateImageVault/` source folder into it.

## Local API

The iOS app points at:

```text
http://127.0.0.1:3000
```

That works for the iOS simulator when the Node.js API is running on the same Mac.
For a physical iPhone, change `APIConfiguration.localDevelopment` to your Mac's
LAN IP address.

Start the backend from the repository root:

```sh
cd server
npm start
```

## Next Milestones

1. Generate/open the Xcode project on a Mac.
2. Test register/login against the local Node.js API.
3. Capture a private image and send it to another registered user.
4. Download received images into the private gallery.
5. Add libsodium encryption after plaintext delivery is proven.

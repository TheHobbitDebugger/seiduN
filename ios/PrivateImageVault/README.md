# PrivateImageVault

PrivateImageVault is the first native iOS slice of the image-only messenger.
This version does not send images to a server yet. It only proves the local rule:
an image can be captured with the camera and saved inside the app sandbox instead
of the standard iOS Photos gallery.

## Current Scope

- Native iOS app written in Swift and SwiftUI.
- Camera capture through `UIImagePickerController`.
- Local image storage in the app's Documents directory.
- No call to `UIImageWriteToSavedPhotosAlbum`.
- No Photos library permission.
- No encryption yet.
- No backend calls yet.

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

## Next Milestones

1. Add account screens.
2. Add the Node.js API client.
3. Upload plaintext images to the self-owned object storage API.
4. Add libsodium encryption after plaintext delivery is proven.

import SwiftUI
import UIKit

/// Errors produced by the camera capture flow.
///
/// These are separate from storage errors because the camera can fail before any
/// file is created.
enum CameraCaptureError: LocalizedError {
    /// The camera did not return a usable still image.
    case missingImage

    var errorDescription: String? {
        switch self {
        case .missingImage:
            return "The camera did not return an image."
        }
    }
}

/// A SwiftUI wrapper around UIKit's camera controller.
///
/// SwiftUI does not provide a full native camera picker by itself, so this type
/// bridges `UIImagePickerController` into the SwiftUI screen hierarchy.
struct CameraCaptureView: UIViewControllerRepresentable {
    /// Called when the user either captures an image or the camera flow fails.
    let onComplete: (Result<UIImage, Error>) -> Void

    /// Allows the representable to close its presentation sheet.
    @Environment(\.dismiss) private var dismiss

    /// Builds the UIKit camera controller.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()

        /// The delegate receives capture/cancel events from UIKit.
        picker.delegate = context.coordinator

        /// This is camera-only. We do not use `.photoLibrary`, so the user is not
        /// selecting existing Photos-gallery images in this first version.
        picker.sourceType = .camera

        /// The app captures still images only. Video support would create a larger
        /// storage and privacy surface, so it is deliberately out of scope.
        picker.cameraCaptureMode = .photo

        /// Editing is disabled so the original camera output goes straight to the
        /// app-private storage pipeline.
        picker.allowsEditing = false

        return picker
    }

    /// Updates are not needed because the camera controller is configured once.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// Creates the coordinator object that acts as the UIKit delegate.
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Handles UIKit callbacks from `UIImagePickerController`.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        /// The parent representable that owns the completion callback.
        private let parent: CameraCaptureView

        /// Stores the parent so delegate events can call back into SwiftUI.
        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        /// Called when the user captures a photo.
        ///
        /// The image is returned to SwiftUI as a `UIImage`. Saving is handled by
        /// `PrivateImageStore`, which keeps storage policy in one auditable place.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onComplete(.failure(CameraCaptureError.missingImage))
                parent.dismiss()
                return
            }

            parent.onComplete(.success(image))
            parent.dismiss()
        }

        /// Called when the user cancels camera capture.
        ///
        /// Cancel is not treated as an error because no image was created and no file
        /// should be written.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

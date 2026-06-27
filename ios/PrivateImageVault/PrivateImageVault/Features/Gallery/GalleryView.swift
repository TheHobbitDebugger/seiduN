import SwiftUI
import UIKit

/// The main screen for capturing and viewing app-private images.
///
/// This view intentionally works only with `PrivateImageStore`. It does not call
/// Photos APIs, and it does not request Photos library permission.
struct GalleryView: View {
    /// The shared store that owns private image files.
    @EnvironmentObject private var imageStore: PrivateImageStore

    /// Controls whether the camera sheet is visible.
    @State private var isCameraPresented = false

    /// Holds a user-visible error message when capture or storage fails.
    @State private var errorMessage: String?

    /// Adaptive columns keep the gallery usable across iPhone sizes.
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if imageStore.images.isEmpty {
                    /// The empty state is local only and does not describe security mechanics.
                    ContentUnavailableView(
                        "No Images",
                        systemImage: "photo.on.rectangle"
                    )
                } else {
                    /// The gallery reads thumbnails from files in the app sandbox.
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(imageStore.images) { image in
                                PrivateImageTile(
                                    image: image,
                                    onDelete: {
                                        imageStore.delete(image)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Private Vault")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openCameraIfAvailable()
                    } label: {
                        Label("Take Picture", systemImage: "camera")
                    }
                }
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraCaptureView { result in
                    handleCaptureResult(result)
                }
            }
            .alert("Image Not Saved", isPresented: hasErrorMessage) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    /// Converts the optional error text into a binding required by SwiftUI alerts.
    private var hasErrorMessage: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    /// Presents the camera only when the current device has one.
    ///
    /// The iOS simulator normally has no camera, so this check prevents a runtime crash
    /// while still keeping the app camera-only on real devices.
    private func openCameraIfAvailable() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "Camera is not available on this device."
            return
        }

        isCameraPresented = true
    }

    /// Handles the image returned by the camera.
    ///
    /// A successful capture is immediately handed to `PrivateImageStore`, which saves
    /// it inside the app sandbox rather than Photos.
    private func handleCaptureResult(_ result: Result<UIImage, Error>) {
        switch result {
        case .success(let image):
            do {
                try imageStore.saveCapturedImage(image)
            } catch {
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

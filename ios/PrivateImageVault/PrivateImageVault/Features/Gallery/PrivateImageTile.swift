import SwiftUI
import UIKit

/// A single thumbnail cell in the private gallery.
///
/// The tile loads image bytes from the app sandbox path stored in `PrivateImage`.
struct PrivateImageTile: View {
    /// The private image represented by this tile.
    let image: PrivateImage

    /// Called when the user chooses to delete the private image file.
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            /// The thumbnail view reads the JPEG from local app storage.
            PrivateImageThumbnail(fileURL: image.fileURL)
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            /// Delete is included early so test images can be removed without touching Photos.
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .frame(minHeight: 120)
    }
}

/// Renders a local JPEG file as a SwiftUI image.
///
/// The view loads with `UIImage(contentsOfFile:)`, which reads from the app's own
/// file path and does not involve the Photos library.
private struct PrivateImageThumbnail: View {
    /// The app-private JPEG file to display.
    let fileURL: URL

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: fileURL.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            /// If the file is missing or corrupt, show a stable placeholder instead of crashing.
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .overlay {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

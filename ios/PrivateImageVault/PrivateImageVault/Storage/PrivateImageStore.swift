import Combine
import Foundation
import UIKit

/// Errors that can happen while converting or saving a captured image.
///
/// Keeping these errors explicit makes it easier to show a useful message in the UI
/// and easier to test each failure case later.
enum PrivateImageStoreError: LocalizedError {
    /// The captured `UIImage` could not be converted to JPEG bytes.
    case jpegEncodingFailed

    /// A file in the private image directory did not use the expected UUID file name.
    case invalidFileName

    var errorDescription: String? {
        switch self {
        case .jpegEncodingFailed:
            return "The captured image could not be saved as JPEG data."
        case .invalidFileName:
            return "The saved image file name is not valid."
        }
    }
}

/// Manages all image files saved inside the app sandbox.
///
/// This class is the only place that writes captured images to disk. Keeping all
/// storage in one type helps us audit that we never write to the Photos gallery.
@MainActor
final class PrivateImageStore: ObservableObject {
    /// The images currently available in the private gallery.
    ///
    /// `private(set)` lets views read the gallery list while forcing writes through
    /// this store's save/delete methods.
    @Published private(set) var images: [PrivateImage] = []

    /// The system file manager used to create directories, write files, and inspect metadata.
    private let fileManager: FileManager

    /// The folder name under Documents where private captures are stored.
    ///
    /// This subfolder keeps app-created images separate from any future app files.
    private let directoryName = "PrivateCaptures"

    /// Creates the image store and loads any images that were already saved.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        ensureStorageDirectoryExists()
        reloadImages()
    }

    /// Saves a captured camera image inside the app's private Documents directory.
    ///
    /// This method intentionally uses `Data.write(to:)` and never calls
    /// `UIImageWriteToSavedPhotosAlbum`, so the image is not added to the standard
    /// iOS Photos gallery.
    func saveCapturedImage(_ image: UIImage) throws {
        /// JPEG keeps the MVP simple and compatible with later upload APIs.
        guard let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw PrivateImageStoreError.jpegEncodingFailed
        }

        /// A UUID file name avoids leaking user-provided names or camera metadata in the path.
        let imageID = UUID()
        let fileURL = storageDirectoryURL()
            .appendingPathComponent(imageID.uuidString)
            .appendingPathExtension("jpg")

        /// `.atomic` writes to a temporary file first, then moves it into place.
        /// `.completeFileProtection` asks iOS to keep the file protected while locked.
        try jpegData.write(to: fileURL, options: [.atomic, .completeFileProtection])

        /// Excluding private captures from device backups reduces accidental spread
        /// beyond this device. We can revisit this when encrypted backup exists.
        try markFileAsExcludedFromBackup(fileURL)

        /// Refresh the published gallery list after the new file exists on disk.
        reloadImages()
    }

    /// Deletes a private image from the app sandbox.
    ///
    /// The delete operation only removes the app-owned file. It never touches Photos
    /// because these images were never saved there.
    func delete(_ image: PrivateImage) {
        do {
            try fileManager.removeItem(at: image.fileURL)
            reloadImages()
        } catch {
            /// In this MVP we keep deletion failure non-fatal and simply leave the list unchanged.
            /// A production app should report this through a user-visible error state.
            reloadImages()
        }
    }

    /// Rebuilds the in-memory gallery list from files currently stored on disk.
    ///
    /// Reading from disk on launch means the app does not need a database for this first slice.
    func reloadImages() {
        let directoryURL = storageDirectoryURL()

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            images = fileURLs
                .filter { $0.pathExtension.lowercased() == "jpg" }
                .compactMap { makePrivateImage(from: $0) }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            /// If the directory cannot be read, expose an empty gallery instead of crashing.
            /// A later version can surface this through a dedicated error banner.
            images = []
        }
    }

    /// Creates the private image folder if this is the first app launch.
    private func ensureStorageDirectoryExists() {
        let directoryURL = storageDirectoryURL()

        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            /// The UI will show an empty gallery if the folder cannot be created.
            /// A later architecture pass can add central error reporting.
        }
    }

    /// Returns the app-private directory used for captured images.
    ///
    /// `documentDirectory` is inside this app's sandbox. It is not the user's Photos
    /// library, and it does not require Photos permission.
    private func storageDirectoryURL() -> URL {
        let documentsDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        return documentsDirectory.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
    }

    /// Builds a `PrivateImage` model from a saved JPEG file.
    private func makePrivateImage(from fileURL: URL) -> PrivateImage? {
        guard let imageID = UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) else {
            return nil
        }

        let createdAt = creationDate(for: fileURL) ?? Date.distantPast

        return PrivateImage(
            id: imageID,
            fileURL: fileURL,
            createdAt: createdAt
        )
    }

    /// Reads the file creation date used by the gallery sort order.
    private func creationDate(for fileURL: URL) -> Date? {
        let values = try? fileURL.resourceValues(forKeys: [.creationDateKey])
        return values?.creationDate
    }

    /// Marks a private image as excluded from iCloud/iTunes backup.
    ///
    /// This keeps the first version conservative: captured images stay local unless
    /// a future encrypted sync/backup design is added intentionally.
    private func markFileAsExcludedFromBackup(_ fileURL: URL) throws {
        var mutableURL = fileURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try mutableURL.setResourceValues(resourceValues)
    }
}

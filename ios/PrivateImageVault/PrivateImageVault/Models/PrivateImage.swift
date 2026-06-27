import Foundation

/// A lightweight model for one image saved inside the app sandbox.
///
/// The model stores only local metadata. It does not represent a Photos-library
/// asset and does not contain anything that points to the standard iOS gallery.
struct PrivateImage: Identifiable, Hashable {
    /// A stable identifier derived from the saved file name.
    let id: UUID

    /// The exact file URL inside the app's private Documents directory.
    let fileURL: URL

    /// The file creation date, used to sort the gallery newest-first.
    let createdAt: Date
}

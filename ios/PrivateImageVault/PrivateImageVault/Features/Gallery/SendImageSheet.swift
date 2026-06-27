import SwiftUI

/// Sheet that uploads one private image and sends it to another user.
///
/// This is still plaintext delivery: the image bytes are uploaded exactly as
/// stored locally. Encryption will later happen before `uploadObject`.
struct SendImageSheet: View {
    /// The app-private image selected from the local gallery.
    let image: PrivateImage

    /// Shared API client used for user search, upload, and message creation.
    @EnvironmentObject private var apiClient: APIClient

    /// Shared image store used to read the selected image bytes from disk.
    @EnvironmentObject private var imageStore: PrivateImageStore

    /// Dismisses the sheet after a successful send.
    @Environment(\.dismiss) private var dismiss

    /// Username typed by the sender.
    @State private var recipientUsername = ""

    /// Whether upload/send is currently running.
    @State private var isSending = false

    /// Last user-visible send error.
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Recipient username", text: $recipientUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        Task {
                            await sendImage()
                        }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                        }
                    }
                    .disabled(isSending)
                }
            }
            .navigationTitle("Send Image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Send Failed", isPresented: hasErrorMessage) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    /// Converts the optional error string into a SwiftUI alert binding.
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

    /// Uploads the selected image and creates the message delivery record.
    @MainActor
    private func sendImage() async {
        isSending = true
        errorMessage = nil

        do {
            let normalizedUsername = recipientUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if normalizedUsername.isEmpty {
                throw APIClientError.localMessage("Enter a recipient username.")
            }

            let users = try await apiClient.searchUsers(username: normalizedUsername)
            guard let recipient = users.first(where: { $0.username.lowercased() == normalizedUsername }) else {
                throw APIClientError.localMessage("No matching user was found.")
            }

            let imageData = try imageStore.imageData(for: image)
            let object = try await apiClient.uploadObject(data: imageData, contentType: "image/jpeg")
            _ = try await apiClient.createImageMessage(
                recipientUserId: recipient.id,
                objectId: object.id
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}

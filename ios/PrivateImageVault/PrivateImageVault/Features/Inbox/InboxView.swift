import SwiftUI

/// Inbox for image messages received from the plaintext API.
struct InboxView: View {
    /// Shared API client used to list messages and download objects.
    @EnvironmentObject private var apiClient: APIClient

    /// Shared local image store used to save downloaded objects inside the app.
    @EnvironmentObject private var imageStore: PrivateImageStore

    /// Messages loaded from the backend.
    @State private var messages: [ImageMessage] = []

    /// Whether the inbox is currently loading.
    @State private var isLoading = false

    /// Last user-visible inbox error.
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if messages.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No Images",
                        systemImage: "tray"
                    )
                } else {
                    ForEach(messages) { message in
                        InboxMessageRow(
                            message: message,
                            onDownload: {
                                Task {
                                    await download(message)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await refresh()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task {
                await refresh()
            }
            .alert("Inbox Error", isPresented: hasErrorMessage) {
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

    /// Reloads the inbox from the backend.
    @MainActor
    private func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            messages = try await apiClient.inbox()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Downloads a message object and stores it in the app-private gallery.
    @MainActor
    private func download(_ message: ImageMessage) async {
        do {
            let data = try await apiClient.downloadObject(objectId: message.objectId)
            try imageStore.saveDownloadedImageData(data)
            _ = try await apiClient.markSeen(messageId: message.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// One row in the received image inbox.
private struct InboxMessageRow: View {
    /// Message metadata displayed by the row.
    let message: ImageMessage

    /// Called when the user wants to save the image into the private gallery.
    let onDownload: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.sender?.username ?? "Unknown")
                    .font(.headline)

                if let object = message.object {
                    Text("\(object.byteSize) bytes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onDownload()
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}

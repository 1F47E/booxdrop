import SwiftUI

struct ContentView: View {
    @State private var manager = DeviceManager()
    @State private var selection = Set<MTPFileInfo.ID>()
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            switch manager.state {
            case .disconnected:
                EmptyStateView()
            case .connecting:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting...")
                        .foregroundStyle(.secondary)
                }
            case .connected:
                FileBrowserView(manager: manager, selection: $selection, showDeleteConfirmation: $showDeleteConfirmation)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if manager.state == .connected {
                    Button(action: { manager.navigateBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(manager.pathStack.count <= 1)

                    // Breadcrumb
                    HStack(spacing: 2) {
                        ForEach(Array(manager.pathStack.enumerated()), id: \.offset) { index, item in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button(item.name) {
                                manager.navigateTo(index: index)
                            }
                            .buttonStyle(.plain)
                            .font(index == manager.pathStack.count - 1 ? .body.bold() : .body)
                        }
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if manager.state == .connected {
                    if let storage = manager.storageInfo.first {
                        Text("\(storage.freeSpaceString) free")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: { manager.refreshFiles() }) {
                        Image(systemName: "arrow.clockwise")
                    }

                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
        .overlay {
            if manager.isTransferring {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(manager.transferProgress)
                        .font(.caption)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Delete \(selection.count) item(s)?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let items = manager.files.filter { selection.contains($0.id) }
                manager.deleteItems(items)
                selection.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear {
            manager.startPolling()
        }
        .onDisappear {
            manager.stopPolling()
        }
    }
}

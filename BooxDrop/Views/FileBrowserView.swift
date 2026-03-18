import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    var manager: DeviceManager
    @Binding var selection: Set<MTPFileInfo.ID>
    @Binding var showDeleteConfirmation: Bool
    @State private var sortOrder = [KeyPathComparator(\MTPFileInfo.name)]
    @State private var isTargeted = false

    var sortedFiles: [MTPFileInfo] {
        // Always keep folders first, then apply sort
        let folders = manager.files.filter { $0.isFolder }.sorted(using: sortOrder)
        let files = manager.files.filter { !$0.isFolder }.sorted(using: sortOrder)
        return folders + files
    }

    var body: some View {
        Table(sortedFiles, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", sortUsing: KeyPathComparator(\MTPFileInfo.name)) { file in
                HStack(spacing: 6) {
                    Image(systemName: file.icon)
                        .foregroundStyle(file.isFolder ? .blue : .secondary)
                        .frame(width: 18)
                    Text(file.name)
                        .lineLimit(1)
                }
                .onTapGesture(count: 2) {
                    if file.isFolder {
                        manager.navigateInto(folder: file)
                    }
                }
            }

            TableColumn("Size", sortUsing: KeyPathComparator(\MTPFileInfo.size)) { file in
                Text(file.sizeString)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80, max: 100)

            TableColumn("Date Modified", sortUsing: KeyPathComparator(\MTPFileInfo.modificationDate)) { file in
                Text(file.dateString)
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150, max: 200)
        }
        .contextMenu(forSelectionType: MTPFileInfo.ID.self) { items in
            if !items.isEmpty {
                Button("Delete", role: .destructive) {
                    selection = items
                    showDeleteConfirmation = true
                }
            }
        } primaryAction: { items in
            // Double-click on folder
            if let id = items.first,
               let file = manager.files.first(where: { $0.id == id }),
               file.isFolder {
                manager.navigateInto(folder: file)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()
            for provider in providers {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    defer { group.leave() }
                    guard let data = data as? Data,
                          let path = String(data: data, encoding: .utf8),
                          let url = URL(string: path) else { return }
                    urls.append(url)
                }
            }
            group.notify(queue: .main) {
                if !urls.isEmpty {
                    manager.uploadFiles(urls: urls)
                }
            }
            return true
        }
        .border(isTargeted ? Color.accentColor : Color.clear, width: 2)
    }
}

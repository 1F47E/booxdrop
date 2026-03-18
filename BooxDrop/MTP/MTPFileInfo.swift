import Foundation

struct MTPFileInfo: Identifiable, Hashable {
    let id: UInt32
    let parentId: UInt32
    let storageId: UInt32
    let name: String
    let size: UInt64
    let isFolder: Bool
    let modificationDate: Date?

    var sizeString: String {
        if isFolder { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var dateString: String {
        guard let date = modificationDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var icon: String {
        if isFolder { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "epub", "azw3", "mobi", "pdf": return "book.fill"
        case "jpg", "jpeg", "png", "gif": return "photo"
        case "mp3", "m4a", "wav", "flac": return "music.note"
        case "mp4", "mkv", "avi": return "film"
        default: return "doc"
        }
    }
}

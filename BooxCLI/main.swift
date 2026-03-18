import Foundation

// MARK: - MTP Wrapper (shared logic with GUI app)

final class MTPDevice {
    private var device: UnsafeMutablePointer<LIBMTP_mtpdevice_t>?

    struct FileInfo {
        let id: UInt32
        let parentId: UInt32
        let storageId: UInt32
        let name: String
        let size: UInt64
        let isFolder: Bool
    }

    struct StorageInfo {
        let id: UInt32
        let description: String
        let capacity: UInt64
        let freeSpace: UInt64
    }

    static func initialize() { LIBMTP_Init() }

    init?() {
        var rawdevs: UnsafeMutablePointer<LIBMTP_raw_device_t>?
        var numdevs: Int32 = 0
        let err = LIBMTP_Detect_Raw_Devices(&rawdevs, &numdevs)
        guard err == LIBMTP_ERROR_NONE, numdevs > 0, let rawdevs = rawdevs else { return nil }
        device = LIBMTP_Open_Raw_Device_Uncached(&rawdevs[0])
        free(rawdevs)
        guard device != nil else { return nil }
        LIBMTP_Get_Storage(device, Int32(LIBMTP_STORAGE_SORTBY_NOTSORTED))
    }

    deinit {
        if let device = device { LIBMTP_Release_Device(device) }
    }

    var defaultStorageId: UInt32 {
        guard let device = device, let storage = device.pointee.storage else { return 0 }
        return storage.pointee.id
    }

    func getStorageInfo() -> [StorageInfo] {
        guard let device = device else { return [] }
        var result: [StorageInfo] = []
        var storage = device.pointee.storage
        while let s = storage {
            let desc = s.pointee.StorageDescription.map { String(cString: $0) } ?? "Storage"
            result.append(StorageInfo(id: s.pointee.id, description: desc,
                                      capacity: s.pointee.MaxCapacity, freeSpace: s.pointee.FreeSpaceInBytes))
            storage = s.pointee.next
        }
        return result
    }

    func listFiles(parentId: UInt32, storageId: UInt32) -> [FileInfo] {
        guard let device = device else { return [] }
        var result: [FileInfo] = []
        var file = LIBMTP_Get_Files_And_Folders(device, storageId, parentId)
        while let f = file {
            let name = f.pointee.filename.map { String(cString: $0) } ?? "(unknown)"
            let isFolder = f.pointee.filetype == LIBMTP_FILETYPE_FOLDER
            result.append(FileInfo(id: f.pointee.item_id, parentId: f.pointee.parent_id,
                                   storageId: f.pointee.storage_id, name: name,
                                   size: f.pointee.filesize, isFolder: isFolder))
            let next = f.pointee.next
            LIBMTP_destroy_file_t(f)
            file = next
        }
        return result.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Resolve a device path like "/Books/Dog Man" to (parentId, storageId)
    func resolve(path: String) -> (parentId: UInt32, storageId: UInt32, name: String)? {
        let storageId = defaultStorageId
        let rootId: UInt32 = 0xFFFFFFFF
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return (rootId, storageId, "/") }

        var currentId = rootId
        for (i, comp) in components.enumerated() {
            let files = listFiles(parentId: currentId, storageId: storageId)
            if let match = files.first(where: { $0.name == comp }) {
                if i == components.count - 1 {
                    return (match.isFolder ? match.id : match.parentId, storageId, match.name)
                }
                guard match.isFolder else { return nil }
                currentId = match.id
            } else {
                // Path component doesn't exist — return parent for creating
                if i == components.count - 1 {
                    return (currentId, storageId, comp)
                }
                return nil
            }
        }
        return (currentId, storageId, components.last ?? "")
    }

    func resolveFolder(path: String) -> (folderId: UInt32, storageId: UInt32)? {
        let storageId = defaultStorageId
        let rootId: UInt32 = 0xFFFFFFFF
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return (rootId, storageId) }

        var currentId = rootId
        for comp in components {
            let files = listFiles(parentId: currentId, storageId: storageId)
            guard let match = files.first(where: { $0.name == comp && $0.isFolder }) else { return nil }
            currentId = match.id
        }
        return (currentId, storageId)
    }

    func resolveFile(path: String) -> FileInfo? {
        let storageId = defaultStorageId
        let rootId: UInt32 = 0xFFFFFFFF
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return nil }

        var currentId = rootId
        for (i, comp) in components.enumerated() {
            let files = listFiles(parentId: currentId, storageId: storageId)
            if let match = files.first(where: { $0.name == comp }) {
                if i == components.count - 1 { return match }
                guard match.isFolder else { return nil }
                currentId = match.id
            } else {
                return nil
            }
        }
        return nil
    }

    func sendFile(localPath: String, parentId: UInt32, storageId: UInt32, filename: String) -> Bool {
        guard let device = device else { return false }
        let fileInfo = LIBMTP_new_file_t()!
        fileInfo.pointee.filename = strdup(filename)
        fileInfo.pointee.parent_id = parentId
        fileInfo.pointee.storage_id = storageId
        fileInfo.pointee.filetype = LIBMTP_FILETYPE_UNKNOWN
        let attrs = try? FileManager.default.attributesOfItem(atPath: localPath)
        fileInfo.pointee.filesize = UInt64(attrs?[.size] as? Int ?? 0)
        let ret = LIBMTP_Send_File_From_File(device, localPath, fileInfo, nil, nil)
        LIBMTP_destroy_file_t(fileInfo)
        return ret == 0
    }

    func createFolder(name: String, parentId: UInt32, storageId: UInt32) -> UInt32 {
        guard let device = device else { return 0 }
        let nameCopy = strdup(name)
        let id = LIBMTP_Create_Folder(device, nameCopy, parentId, storageId)
        free(nameCopy)
        return id
    }

    func deleteObject(id: UInt32) -> Bool {
        guard let device = device else { return false }
        return LIBMTP_Delete_Object(device, id) == 0
    }

    func downloadFile(objectId: UInt32, localPath: String) -> Bool {
        guard let device = device else { return false }
        return LIBMTP_Get_File_To_File(device, objectId, localPath, nil, nil) == 0
    }
}

// MARK: - CLI

func printUsage() {
    let usage = """
    booxcp — MTP file transfer CLI

    Usage:
      booxcp ls [/path]                List files on device
      booxcp cp <local> <device-path>  Copy local file/dir to device
      booxcp get <device-path> <local> Download file from device
      booxcp rm <device-path>          Delete file/folder on device
      booxcp mkdir <device-path>       Create folder on device
      booxcp df                        Show device storage info
      booxcp tree [/path] [depth]      Show directory tree

    Examples:
      booxcp ls /Books
      booxcp cp ~/books/MyBook.epub /Books/
      booxcp cp ~/books/DogMan/ /Books/DogMan
      booxcp get /Books/MyBook.epub ./MyBook.epub
      booxcp rm /Books/OldBook.epub
      booxcp mkdir /Books/NewSeries
      booxcp tree /Books 2
    """
    print(usage)
}

func humanSize(_ bytes: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
}

func connect() -> MTPDevice {
    MTPDevice.initialize()
    guard let dev = MTPDevice() else {
        fputs("Error: No MTP device found. Is it plugged in and set to File Transfer mode?\n", stderr)
        exit(1)
    }
    return dev
}

func cmdLs(dev: MTPDevice, path: String) {
    let folderId: UInt32
    let storageId: UInt32

    if path == "/" || path.isEmpty {
        folderId = 0xFFFFFFFF
        storageId = dev.defaultStorageId
    } else {
        guard let resolved = dev.resolveFolder(path: path) else {
            fputs("Error: Folder not found: \(path)\n", stderr)
            exit(1)
        }
        folderId = resolved.folderId
        storageId = resolved.storageId
    }

    let files = dev.listFiles(parentId: folderId, storageId: storageId)
    if files.isEmpty {
        print("(empty)")
        return
    }
    for f in files {
        let icon = f.isFolder ? "📁" : "📄"
        let size = f.isFolder ? "" : humanSize(f.size)
        print("\(icon) \(f.name)\t\(size)")
    }
    print("\n\(files.count) items")
}

func cmdTree(dev: MTPDevice, path: String, maxDepth: Int) {
    let folderId: UInt32
    let storageId: UInt32

    if path == "/" || path.isEmpty {
        folderId = 0xFFFFFFFF
        storageId = dev.defaultStorageId
    } else {
        guard let resolved = dev.resolveFolder(path: path) else {
            fputs("Error: Folder not found: \(path)\n", stderr)
            exit(1)
        }
        folderId = resolved.folderId
        storageId = resolved.storageId
    }

    func printTree(parentId: UInt32, indent: String, depth: Int) {
        guard depth < maxDepth else { return }
        let files = dev.listFiles(parentId: parentId, storageId: storageId)
        for (i, f) in files.enumerated() {
            let isLast = i == files.count - 1
            let prefix = isLast ? "└── " : "├── "
            let icon = f.isFolder ? "📁" : "📄"
            let size = f.isFolder ? "" : " (\(humanSize(f.size)))"
            print("\(indent)\(prefix)\(icon) \(f.name)\(size)")
            if f.isFolder {
                let nextIndent = indent + (isLast ? "    " : "│   ")
                printTree(parentId: f.id, indent: nextIndent, depth: depth + 1)
            }
        }
    }

    print(path.isEmpty ? "/" : path)
    printTree(parentId: folderId, indent: "", depth: 0)
}

func cmdCp(dev: MTPDevice, localPath: String, devicePath: String) {
    let url = URL(fileURLWithPath: localPath)
    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

    // Figure out target folder and filename
    let targetPath = devicePath.hasSuffix("/") ? devicePath : devicePath
    let components = targetPath.split(separator: "/").map(String.init)

    let parentFolderId: UInt32
    let storageId: UInt32

    // Try to resolve the full path as a folder (uploading into it)
    if let resolved = dev.resolveFolder(path: targetPath) {
        parentFolderId = resolved.folderId
        storageId = resolved.storageId
    } else if components.count > 1 {
        // Try resolving parent
        let parentPath = components.dropLast().joined(separator: "/")
        guard let resolved = dev.resolveFolder(path: parentPath) else {
            fputs("Error: Target folder not found: \(parentPath)\n", stderr)
            exit(1)
        }
        parentFolderId = resolved.folderId
        storageId = resolved.storageId
    } else {
        parentFolderId = 0xFFFFFFFF
        storageId = dev.defaultStorageId
    }

    if isDir {
        uploadDirectory(dev: dev, url: url, parentId: parentFolderId, storageId: storageId)
    } else {
        let filename = url.lastPathComponent
        print("Copying \(filename) (\(humanSize(UInt64(fileSize(url)))))...")
        if dev.sendFile(localPath: url.path, parentId: parentFolderId, storageId: storageId, filename: filename) {
            print("✓ Done")
        } else {
            fputs("✗ Failed to copy \(filename)\n", stderr)
            exit(1)
        }
    }
}

func uploadDirectory(dev: MTPDevice, url: URL, parentId: UInt32, storageId: UInt32) {
    let folderName = url.lastPathComponent
    print("Creating folder: \(folderName)")
    let folderId = dev.createFolder(name: folderName, parentId: parentId, storageId: storageId)
    guard folderId != 0 else {
        fputs("✗ Failed to create folder \(folderName)\n", stderr)
        return
    }

    let contents = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
    for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isDir {
            uploadDirectory(dev: dev, url: item, parentId: folderId, storageId: storageId)
        } else {
            let name = item.lastPathComponent
            print("  Copying \(name) (\(humanSize(UInt64(fileSize(item)))))...")
            if !dev.sendFile(localPath: item.path, parentId: folderId, storageId: storageId, filename: name) {
                fputs("  ✗ Failed: \(name)\n", stderr)
            }
        }
    }
}

func cmdGet(dev: MTPDevice, devicePath: String, localPath: String) {
    guard let file = dev.resolveFile(path: devicePath) else {
        fputs("Error: File not found on device: \(devicePath)\n", stderr)
        exit(1)
    }

    let targetPath: String
    if FileManager.default.isDirectory(localPath) {
        targetPath = (localPath as NSString).appendingPathComponent(file.name)
    } else {
        targetPath = localPath
    }

    print("Downloading \(file.name) (\(humanSize(file.size)))...")
    if dev.downloadFile(objectId: file.id, localPath: targetPath) {
        print("✓ Saved to \(targetPath)")
    } else {
        fputs("✗ Download failed\n", stderr)
        exit(1)
    }
}

func cmdRm(dev: MTPDevice, devicePath: String) {
    guard let file = dev.resolveFile(path: devicePath) else {
        fputs("Error: Not found on device: \(devicePath)\n", stderr)
        exit(1)
    }
    let icon = file.isFolder ? "📁" : "📄"
    print("Deleting \(icon) \(file.name)...")
    if dev.deleteObject(id: file.id) {
        print("✓ Deleted")
    } else {
        fputs("✗ Delete failed\n", stderr)
        exit(1)
    }
}

func cmdMkdir(dev: MTPDevice, devicePath: String) {
    let components = devicePath.split(separator: "/").map(String.init)
    guard !components.isEmpty else {
        fputs("Error: Specify a path\n", stderr)
        exit(1)
    }

    let parentPath = components.dropLast().joined(separator: "/")
    let folderName = components.last!

    let parentId: UInt32
    let storageId: UInt32
    if parentPath.isEmpty {
        parentId = 0xFFFFFFFF
        storageId = dev.defaultStorageId
    } else {
        guard let resolved = dev.resolveFolder(path: parentPath) else {
            fputs("Error: Parent folder not found: \(parentPath)\n", stderr)
            exit(1)
        }
        parentId = resolved.folderId
        storageId = resolved.storageId
    }

    let id = dev.createFolder(name: folderName, parentId: parentId, storageId: storageId)
    if id != 0 {
        print("✓ Created /\(devicePath)")
    } else {
        fputs("✗ Failed to create folder\n", stderr)
        exit(1)
    }
}

func cmdDf(dev: MTPDevice) {
    let storages = dev.getStorageInfo()
    for s in storages {
        let used = s.capacity - s.freeSpace
        let pct = s.capacity > 0 ? Int(Double(used) / Double(s.capacity) * 100) : 0
        print("\(s.description):")
        print("  Total: \(humanSize(s.capacity))")
        print("  Used:  \(humanSize(used)) (\(pct)%)")
        print("  Free:  \(humanSize(s.freeSpace))")
    }
}

func fileSize(_ url: URL) -> Int {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
}

extension FileManager {
    func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    printUsage()
    exit(0)
}

let command = args[1]

switch command {
case "ls":
    let dev = connect()
    let path = args.count > 2 ? args[2] : "/"
    cmdLs(dev: dev, path: path)

case "tree":
    let dev = connect()
    let path = args.count > 2 ? args[2] : "/"
    let depth = args.count > 3 ? Int(args[3]) ?? 3 : 3
    cmdTree(dev: dev, path: path, maxDepth: depth)

case "cp":
    guard args.count >= 4 else {
        fputs("Usage: booxcp cp <local-path> <device-path>\n", stderr)
        exit(1)
    }
    let dev = connect()
    cmdCp(dev: dev, localPath: args[2], devicePath: args[3])

case "get":
    guard args.count >= 4 else {
        fputs("Usage: booxcp get <device-path> <local-path>\n", stderr)
        exit(1)
    }
    let dev = connect()
    cmdGet(dev: dev, devicePath: args[2], localPath: args[3])

case "rm":
    guard args.count >= 3 else {
        fputs("Usage: booxcp rm <device-path>\n", stderr)
        exit(1)
    }
    let dev = connect()
    cmdRm(dev: dev, devicePath: args[2])

case "mkdir":
    guard args.count >= 3 else {
        fputs("Usage: booxcp mkdir <device-path>\n", stderr)
        exit(1)
    }
    let dev = connect()
    cmdMkdir(dev: dev, devicePath: args[2])

case "df":
    let dev = connect()
    cmdDf(dev: dev)

case "help", "-h", "--help":
    printUsage()

default:
    fputs("Unknown command: \(command)\n", stderr)
    printUsage()
    exit(1)
}

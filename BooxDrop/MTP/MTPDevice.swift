import Foundation

final class MTPDevice {
    private var device: UnsafeMutablePointer<LIBMTP_mtpdevice_t>?

    struct StorageInfo {
        let id: UInt32
        let description: String
        let capacity: UInt64
        let freeSpace: UInt64

        var usedSpace: UInt64 { capacity - freeSpace }

        var capacityString: String {
            ByteCountFormatter.string(fromByteCount: Int64(capacity), countStyle: .file)
        }
        var freeSpaceString: String {
            ByteCountFormatter.string(fromByteCount: Int64(freeSpace), countStyle: .file)
        }
    }

    static func initialize() {
        LIBMTP_Init()
    }

    static func detectDevices() -> Bool {
        var rawdevs: UnsafeMutablePointer<LIBMTP_raw_device_t>?
        var numdevs: Int32 = 0
        let err = LIBMTP_Detect_Raw_Devices(&rawdevs, &numdevs)
        if let rawdevs = rawdevs { free(rawdevs) }
        return err == LIBMTP_ERROR_NONE && numdevs > 0
    }

    init?() {
        var rawdevs: UnsafeMutablePointer<LIBMTP_raw_device_t>?
        var numdevs: Int32 = 0
        let err = LIBMTP_Detect_Raw_Devices(&rawdevs, &numdevs)
        guard err == LIBMTP_ERROR_NONE, numdevs > 0, let rawdevs = rawdevs else {
            return nil
        }
        device = LIBMTP_Open_Raw_Device_Uncached(&rawdevs[0])
        free(rawdevs)
        guard device != nil else { return nil }
        LIBMTP_Get_Storage(device, Int32(LIBMTP_STORAGE_SORTBY_NOTSORTED))
    }

    deinit {
        if let device = device {
            LIBMTP_Release_Device(device)
        }
    }

    var friendlyName: String {
        guard let device = device,
              let name = LIBMTP_Get_Friendlyname(device) else { return "MTP Device" }
        let str = String(cString: name)
        free(name)
        return str.isEmpty ? "MTP Device" : str
    }

    var modelName: String {
        guard let device = device,
              let name = LIBMTP_Get_Modelname(device) else { return "Unknown" }
        let str = String(cString: name)
        free(name)
        return str
    }

    func getStorageInfo() -> [StorageInfo] {
        guard let device = device else { return [] }
        var result: [StorageInfo] = []
        var storage = device.pointee.storage
        while let s = storage {
            let desc: String
            if let d = s.pointee.StorageDescription {
                desc = String(cString: d)
            } else {
                desc = "Storage"
            }
            result.append(StorageInfo(
                id: s.pointee.id,
                description: desc,
                capacity: s.pointee.MaxCapacity,
                freeSpace: s.pointee.FreeSpaceInBytes
            ))
            storage = s.pointee.next
        }
        return result
    }

    var defaultStorageId: UInt32 {
        guard let device = device, let storage = device.pointee.storage else { return 0 }
        return storage.pointee.id
    }

    func listFiles(parentId: UInt32, storageId: UInt32) -> [MTPFileInfo] {
        guard let device = device else { return [] }
        var result: [MTPFileInfo] = []

        let files = LIBMTP_Get_Files_And_Folders(device, storageId, parentId)
        var file = files
        while let f = file {
            let name: String
            if let fn = f.pointee.filename {
                name = String(cString: fn)
            } else {
                name = "(unknown)"
            }

            let isFolder = f.pointee.filetype == LIBMTP_FILETYPE_FOLDER
            let modDate: Date?
            if f.pointee.modificationdate > 0 {
                modDate = Date(timeIntervalSince1970: TimeInterval(f.pointee.modificationdate))
            } else {
                modDate = nil
            }

            result.append(MTPFileInfo(
                id: f.pointee.item_id,
                parentId: f.pointee.parent_id,
                storageId: f.pointee.storage_id,
                name: name,
                size: f.pointee.filesize,
                isFolder: isFolder,
                modificationDate: modDate
            ))

            let next = f.pointee.next
            LIBMTP_destroy_file_t(f)
            file = next
        }

        return result.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    func sendFile(localPath: String, parentId: UInt32, storageId: UInt32, filename: String) -> Bool {
        guard let device = device else { return false }

        let fileInfo = LIBMTP_new_file_t()
        guard let fileInfo = fileInfo else { return false }

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
        let folderId = LIBMTP_Create_Folder(device, nameCopy, parentId, storageId)
        free(nameCopy)
        return folderId
    }

    func deleteObject(id: UInt32) -> Bool {
        guard let device = device else { return false }
        return LIBMTP_Delete_Object(device, id) == 0
    }
}

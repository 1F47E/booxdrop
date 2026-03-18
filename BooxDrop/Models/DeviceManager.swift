import Foundation
import SwiftUI

@Observable
final class DeviceManager {
    enum State {
        case disconnected
        case connecting
        case connected
    }

    var state: State = .disconnected
    var device: MTPDevice?
    var deviceName: String = ""
    var storageInfo: [MTPDevice.StorageInfo] = []
    var currentStorageId: UInt32 = 0
    var currentParentId: UInt32 = 0xFFFFFFFF // LIBMTP_FILES_AND_FOLDERS_ROOT
    var pathStack: [(name: String, parentId: UInt32)] = []
    var files: [MTPFileInfo] = []
    var isTransferring = false
    var transferProgress: String = ""
    var errorMessage: String?

    private var pollTimer: Timer?

    func startPolling() {
        MTPDevice.initialize()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkDevice()
        }
        checkDevice()
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkDevice() {
        if state == .disconnected || state == .connecting {
            if MTPDevice.detectDevices() {
                connect()
            }
        } else if state == .connected {
            if !MTPDevice.detectDevices() {
                disconnect()
            }
        }
    }

    func connect() {
        state = .connecting
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let dev = MTPDevice()
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let dev = dev {
                    self.device = dev
                    self.deviceName = dev.modelName
                    self.storageInfo = dev.getStorageInfo()
                    self.currentStorageId = dev.defaultStorageId
                    self.currentParentId = 0xFFFFFFFF
                    self.pathStack = [(name: "Root", parentId: 0xFFFFFFFF)]
                    self.state = .connected
                    self.refreshFiles()
                } else {
                    self.state = .disconnected
                }
            }
        }
    }

    func disconnect() {
        device = nil
        state = .disconnected
        files = []
        pathStack = []
        storageInfo = []
        deviceName = ""
    }

    func refreshFiles() {
        guard let device = device else { return }
        let storageId = currentStorageId
        let parentId = currentParentId
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = device.listFiles(parentId: parentId, storageId: storageId)
            DispatchQueue.main.async {
                self?.files = items
            }
        }
    }

    func navigateInto(folder: MTPFileInfo) {
        guard folder.isFolder else { return }
        pathStack.append((name: folder.name, parentId: folder.id))
        currentParentId = folder.id
        refreshFiles()
    }

    func navigateBack() {
        guard pathStack.count > 1 else { return }
        pathStack.removeLast()
        currentParentId = pathStack.last!.parentId
        refreshFiles()
    }

    func navigateTo(index: Int) {
        guard index < pathStack.count else { return }
        pathStack = Array(pathStack.prefix(index + 1))
        currentParentId = pathStack.last!.parentId
        refreshFiles()
    }

    func uploadFiles(urls: [URL]) {
        guard let device = device else { return }
        isTransferring = true
        let parentId = currentParentId
        let storageId = currentStorageId

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for (i, url) in urls.enumerated() {
                let filename = url.lastPathComponent
                DispatchQueue.main.async {
                    self?.transferProgress = "Copying \(i + 1)/\(urls.count): \(filename)"
                }

                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                if isDir {
                    self?.uploadDirectory(device: device, url: url, parentId: parentId, storageId: storageId)
                } else {
                    _ = device.sendFile(
                        localPath: url.path,
                        parentId: parentId,
                        storageId: storageId,
                        filename: filename
                    )
                }
            }

            DispatchQueue.main.async {
                self?.isTransferring = false
                self?.transferProgress = ""
                self?.refreshFiles()
                self?.storageInfo = device.getStorageInfo()
            }
        }
    }

    private func uploadDirectory(device: MTPDevice, url: URL, parentId: UInt32, storageId: UInt32) {
        let folderName = url.lastPathComponent
        let folderId = device.createFolder(name: folderName, parentId: parentId, storageId: storageId)
        guard folderId != 0 else { return }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []

        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                uploadDirectory(device: device, url: item, parentId: folderId, storageId: storageId)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.transferProgress = "Copying: \(item.lastPathComponent)"
                }
                _ = device.sendFile(
                    localPath: item.path,
                    parentId: folderId,
                    storageId: storageId,
                    filename: item.lastPathComponent
                )
            }
        }
    }

    func deleteItems(_ items: [MTPFileInfo]) {
        guard let device = device else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for item in items {
                _ = device.deleteObject(id: item.id)
            }
            DispatchQueue.main.async {
                self?.refreshFiles()
                if let dev = self?.device {
                    self?.storageInfo = dev.getStorageInfo()
                }
            }
        }
    }
}

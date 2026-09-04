import Darwin
import Dispatch
import Foundation

/// Watches both the file and its containing directory. The file descriptor
/// catches in-place writes; the directory descriptor catches atomic-save
/// replacements, which create a new inode under the same filename.
final class FileChangeMonitor {
    private struct FileSignature: Equatable {
        let device: UInt64
        let inode: UInt64
        let size: Int64
        let modifiedSeconds: Int64
        let modifiedNanoseconds: Int64
    }

    private let fileURL: URL
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "ch.epfl.realsizepreviewer.file-monitor")
    private var fileSource: DispatchSourceFileSystemObject?
    private var directorySource: DispatchSourceFileSystemObject?
    private var pendingCheck: DispatchWorkItem?
    private var lastSignature: FileSignature?
    private var isRunning = false

    init(fileURL: URL, onChange: @escaping () -> Void) {
        self.fileURL = fileURL.standardizedFileURL
        self.onChange = onChange
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastSignature = Self.signature(for: fileURL)
        installDirectorySource()
        installFileSource()
    }

    func stop() {
        isRunning = false
        pendingCheck?.cancel()
        pendingCheck = nil
        fileSource?.cancel()
        fileSource = nil
        directorySource?.cancel()
        directorySource = nil
    }

    deinit {
        stop()
    }

    private func installFileSource() {
        fileSource?.cancel()
        fileSource = nil

        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename, .delete, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleSignatureCheck()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        fileSource = source
        source.resume()
    }

    private func installDirectorySource() {
        let directoryURL = fileURL.deletingLastPathComponent()
        let descriptor = open(directoryURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .attrib, .rename, .delete, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleSignatureCheck()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        directorySource = source
        source.resume()
    }

    private func scheduleSignatureCheck(after delay: DispatchTimeInterval = .milliseconds(300)) {
        guard isRunning else { return }
        pendingCheck?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.checkSignature(retriesRemaining: 5)
        }
        pendingCheck = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func checkSignature(retriesRemaining: Int) {
        guard isRunning else { return }
        guard let signature = Self.signature(for: fileURL) else {
            if retriesRemaining > 0 {
                let workItem = DispatchWorkItem { [weak self] in
                    self?.checkSignature(retriesRemaining: retriesRemaining - 1)
                }
                pendingCheck = workItem
                queue.asyncAfter(deadline: .now() + .milliseconds(300), execute: workItem)
            }
            return
        }

        guard signature != lastSignature else { return }
        let inodeChanged = signature.inode != lastSignature?.inode
            || signature.device != lastSignature?.device
        lastSignature = signature

        if inodeChanged {
            installFileSource()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRunning else { return }
            self.onChange()
        }
    }

    private static func signature(for url: URL) -> FileSignature? {
        var information = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return lstat(path, &information)
        }
        guard result == 0 else { return nil }

        return FileSignature(
            device: UInt64(information.st_dev),
            inode: UInt64(information.st_ino),
            size: Int64(information.st_size),
            modifiedSeconds: Int64(information.st_mtimespec.tv_sec),
            modifiedNanoseconds: Int64(information.st_mtimespec.tv_nsec)
        )
    }
}

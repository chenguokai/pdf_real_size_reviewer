import Foundation
import XCTest
@testable import RealSizePreviewer

final class FileChangeMonitorTests: XCTestCase {
    func testDetectsInPlaceFileWrite() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let changed = expectation(description: "in-place write detected")
        let monitor = FileChangeMonitor(fileURL: fixture.file) {
            changed.fulfill()
        }
        monitor.start()

        try Data("updated contents".utf8).write(to: fixture.file, options: [])
        wait(for: [changed], timeout: 3)
        monitor.stop()
    }

    func testDetectsAtomicFileReplacement() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let changed = expectation(description: "atomic replacement detected")
        let monitor = FileChangeMonitor(fileURL: fixture.file) {
            changed.fulfill()
        }
        monitor.start()

        try Data("replacement".utf8).write(to: fixture.file, options: .atomic)
        wait(for: [changed], timeout: 3)
        monitor.stop()
    }

    private func makeFixture() throws -> (directory: URL, file: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("real-size-monitor-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("document.pdf")
        try Data("initial".utf8).write(to: file)
        return (directory, file)
    }
}

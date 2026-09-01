import AppKit
import Combine
import CoreGraphics

enum DisplayMeasurementMode: String, CaseIterable, Identifiable {
    case measuredWidth = "Measured width"
    case diagonal = "Diagonal"

    var id: String { rawValue }
}

@MainActor
final class DisplayCalibration: ObservableObject {
    @Published private(set) var displayName = "Current display"
    @Published private(set) var displayID: CGDirectDisplayID = CGMainDisplayID()
    @Published private(set) var logicalSizePoints = CGSize(width: 1440, height: 900)
    @Published private(set) var pixelSize = CGSize(width: 2880, height: 1800)
    @Published private(set) var backingScaleFactor: CGFloat = 2
    @Published private(set) var detectedPhysicalSizeMM = CGSize.zero

    @Published var measurementMode: DisplayMeasurementMode = .measuredWidth {
        didSet { persist() }
    }
    @Published var measuredWidthMM: Double = 300 {
        didSet { persist() }
    }
    @Published var diagonalInches: Double = 13.3 {
        didSet { persist() }
    }

    private let defaults = UserDefaults.standard
    private var isLoading = false

    init() {
        if let screen = NSScreen.main {
            update(for: screen)
        }
    }

    var effectivePhysicalWidthMM: Double {
        switch measurementMode {
        case .measuredWidth:
            return measuredWidthMM > 0 ? measuredWidthMM : fallbackWidthMM
        case .diagonal:
            let result = ScaleCalculator.physicalWidthFromDiagonal(
                diagonalInches: diagonalInches,
                pixelWidth: Int(pixelSize.width),
                pixelHeight: Int(pixelSize.height)
            )
            return result > 0 ? result : fallbackWidthMM
        }
    }

    var pointsPerMillimeter: CGFloat {
        ScaleCalculator.logicalPointsPerMillimeter(
            logicalScreenWidth: logicalSizePoints.width,
            physicalScreenWidthMM: effectivePhysicalWidthMM
        )
    }

    var calibrationSummary: String {
        let physical = effectivePhysicalWidthMM
        let inches = physical / ScaleCalculator.millimetersPerInch
        return String(format: "%.1f mm wide  •  %.2f in", physical, inches)
    }

    func update(for screen: NSScreen) {
        let newID = Self.displayID(for: screen)
        let changedDisplay = newID != displayID || displayName != screen.localizedName
        let newLogicalSize = screen.frame.size
        let newBackingScaleFactor = screen.backingScaleFactor
        let newPixelSize = CGSize(
            width: CGDisplayPixelsWide(newID),
            height: CGDisplayPixelsHigh(newID)
        )
        let newDetectedPhysicalSize = CGDisplayScreenSize(newID)

        // Screen notifications can be delivered repeatedly while a window moves.
        // Only publish values that actually changed so SwiftUI cannot enter an
        // observation -> publication -> render feedback loop.
        if displayID != newID { displayID = newID }
        if displayName != screen.localizedName { displayName = screen.localizedName }
        if logicalSizePoints != newLogicalSize { logicalSizePoints = newLogicalSize }
        if backingScaleFactor != newBackingScaleFactor {
            backingScaleFactor = newBackingScaleFactor
        }
        if pixelSize != newPixelSize { pixelSize = newPixelSize }
        if detectedPhysicalSizeMM != newDetectedPhysicalSize {
            detectedPhysicalSizeMM = newDetectedPhysicalSize
        }

        guard changedDisplay else { return }
        loadCalibration()
    }

    func useDetectedSize() {
        guard detectedPhysicalSizeMM.width > 0 else { return }
        measurementMode = .measuredWidth
        measuredWidthMM = detectedPhysicalSizeMM.width
        diagonalInches = hypot(
            detectedPhysicalSizeMM.width,
            detectedPhysicalSizeMM.height
        ) / ScaleCalculator.millimetersPerInch
    }

    private var fallbackWidthMM: Double {
        if detectedPhysicalSizeMM.width > 0 {
            return detectedPhysicalSizeMM.width
        }
        return 300
    }

    private func loadCalibration() {
        isLoading = true
        defer { isLoading = false }

        let prefix = defaultsPrefix
        if let storedMode = defaults.string(forKey: "\(prefix).mode"),
           let mode = DisplayMeasurementMode(rawValue: storedMode) {
            measurementMode = mode
        } else {
            measurementMode = .measuredWidth
        }

        let storedWidth = defaults.double(forKey: "\(prefix).widthMM")
        measuredWidthMM = storedWidth > 0 ? storedWidth : fallbackWidthMM

        let storedDiagonal = defaults.double(forKey: "\(prefix).diagonalInches")
        if storedDiagonal > 0 {
            diagonalInches = storedDiagonal
        } else if detectedPhysicalSizeMM.width > 0 {
            diagonalInches = hypot(
                detectedPhysicalSizeMM.width,
                detectedPhysicalSizeMM.height
            ) / ScaleCalculator.millimetersPerInch
        }
    }

    private func persist() {
        guard !isLoading else { return }
        let prefix = defaultsPrefix
        defaults.set(measurementMode.rawValue, forKey: "\(prefix).mode")
        defaults.set(measuredWidthMM, forKey: "\(prefix).widthMM")
        defaults.set(diagonalInches, forKey: "\(prefix).diagonalInches")
    }

    private var defaultsPrefix: String {
        "displayCalibration.\(displayID)"
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }
}

import CoreGraphics
import XCTest
@testable import RealSizePreviewer

final class ScaleCalculatorTests: XCTestCase {
    func testLargeISOAPaperPresetsHaveStandardDimensions() {
        XCTAssertEqual(PaperPreset.a0.portraitSizeMM, CGSize(width: 841, height: 1189))
        XCTAssertEqual(PaperPreset.a1.portraitSizeMM, CGSize(width: 594, height: 841))
        XCTAssertEqual(PaperPreset.a2.portraitSizeMM, CGSize(width: 420, height: 594))
    }

    func testPaperPresetMatchingAcceptsBothOrientations() {
        XCTAssertTrue(PaperPreset.a2.matches(CGSize(width: 420, height: 594)))
        XCTAssertTrue(PaperPreset.a2.matches(CGSize(width: 594, height: 420)))
        XCTAssertFalse(PaperPreset.a2.matches(CGSize(width: 500, height: 500)))
    }

    func testIntrinsicPDFSizeUsesSeventyTwoPointsPerInch() {
        let oneInchSquare = CGSize(width: 72, height: 72)
        let millimeters = ScaleCalculator.intrinsicMillimeters(forPDFSize: oneInchSquare)

        XCTAssertEqual(millimeters.width, 25.4, accuracy: 0.0001)
        XCTAssertEqual(millimeters.height, 25.4, accuracy: 0.0001)
    }

    func testRealSizeScaleUsesLogicalPointsAndNotBackingPixels() {
        let scale = ScaleCalculator.pdfViewScaleFactor(
            pdfSizePoints: CGSize(width: 72, height: 72),
            targetSizeMM: CGSize(width: 25.4, height: 25.4),
            proportionsLocked: true,
            logicalScreenWidth: 1440,
            physicalScreenWidthMM: 300
        )

        // 1 PDF inch should occupy 25.4 mm. A 300 mm-wide screen represented
        // by 1440 AppKit points has 4.8 logical points per millimetre.
        XCTAssertEqual(scale, 25.4 / 72 * 4.8, accuracy: 0.0001)
    }

    func testFitToSheetPreservesPDFAspectRatio() {
        let pdf = CGSize(width: 200, height: 100)
        let target = CGSize(width: 100, height: 100)
        let effective = ScaleCalculator.effectivePrintedSize(
            pdfSizePoints: pdf,
            targetSizeMM: target,
            proportionsLocked: false
        )

        XCTAssertEqual(effective.width, 100, accuracy: 0.0001)
        XCTAssertEqual(effective.height, 50, accuracy: 0.0001)
    }

    func testDiagonalMeasurementUsesNativePixelAspectRatio() {
        let width = ScaleCalculator.physicalWidthFromDiagonal(
            diagonalInches: 10,
            pixelWidth: 1600,
            pixelHeight: 900
        )
        let expected = 10 * 25.4 * 1600 / hypot(1600.0, 900.0)

        XCTAssertEqual(width, expected, accuracy: 0.0001)
    }

    func testPreviewZoomIsSeparateFromPhysicalCalibration() {
        let base = ScaleCalculator.pdfViewScaleFactor(
            pdfSizePoints: CGSize(width: 600, height: 800),
            targetSizeMM: CGSize(width: 210, height: 280),
            proportionsLocked: true,
            logicalScreenWidth: 1512,
            physicalScreenWidthMM: 286,
            previewZoom: 1
        )
        let doubled = ScaleCalculator.pdfViewScaleFactor(
            pdfSizePoints: CGSize(width: 600, height: 800),
            targetSizeMM: CGSize(width: 210, height: 280),
            proportionsLocked: true,
            logicalScreenWidth: 1512,
            physicalScreenWidthMM: 286,
            previewZoom: 2
        )

        XCTAssertEqual(doubled, base * 2, accuracy: 0.0001)
    }

    func testManualPDFViewScaleCanBeConvertedBackToPreviewZoom() {
        let zoom = ScaleCalculator.previewZoom(
            pdfViewScaleFactor: 3.75,
            actualSizeScaleFactor: 1.5
        )

        XCTAssertEqual(zoom, 2.5, accuracy: 0.0001)
    }
}

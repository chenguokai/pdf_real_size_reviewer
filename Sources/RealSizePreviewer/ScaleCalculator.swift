import CoreGraphics
import Foundation

/// Pure unit conversions used by the UI and covered by unit tests.
enum ScaleCalculator {
    static let millimetersPerInch = 25.4
    static let pdfPointsPerInch = 72.0

    static func logicalPointsPerMillimeter(
        logicalScreenWidth: CGFloat,
        physicalScreenWidthMM: Double
    ) -> CGFloat {
        guard logicalScreenWidth > 0, physicalScreenWidthMM > 0 else { return 1 }
        return logicalScreenWidth / CGFloat(physicalScreenWidthMM)
    }

    static func physicalWidthFromDiagonal(
        diagonalInches: Double,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> Double {
        guard diagonalInches > 0, pixelWidth > 0, pixelHeight > 0 else { return 0 }
        let width = Double(pixelWidth)
        let height = Double(pixelHeight)
        let widthFraction = width / hypot(width, height)
        return diagonalInches * millimetersPerInch * widthFraction
    }

    static func intrinsicMillimeters(forPDFSize size: CGSize) -> CGSize {
        CGSize(
            width: size.width * millimetersPerInch / pdfPointsPerInch,
            height: size.height * millimetersPerInch / pdfPointsPerInch
        )
    }

    /// Returns physical millimetres represented by one PDF point.
    /// When proportions are unlocked, the PDF is fitted into the target sheet.
    static func millimetersPerPDFPoint(
        pdfSizePoints: CGSize,
        targetSizeMM: CGSize,
        proportionsLocked: Bool
    ) -> CGFloat {
        guard pdfSizePoints.width > 0,
              pdfSizePoints.height > 0,
              targetSizeMM.width > 0,
              targetSizeMM.height > 0 else { return 0 }

        let widthScale = targetSizeMM.width / pdfSizePoints.width
        if proportionsLocked {
            return widthScale
        }

        let heightScale = targetSizeMM.height / pdfSizePoints.height
        return min(widthScale, heightScale)
    }

    static func effectivePrintedSize(
        pdfSizePoints: CGSize,
        targetSizeMM: CGSize,
        proportionsLocked: Bool
    ) -> CGSize {
        let scale = millimetersPerPDFPoint(
            pdfSizePoints: pdfSizePoints,
            targetSizeMM: targetSizeMM,
            proportionsLocked: proportionsLocked
        )
        return CGSize(width: pdfSizePoints.width * scale, height: pdfSizePoints.height * scale)
    }

    /// `PDFView.scaleFactor` is PDF points -> AppKit logical points. AppKit then
    /// maps logical points to Retina backing pixels, so no manual 2× multiplier is used.
    static func pdfViewScaleFactor(
        pdfSizePoints: CGSize,
        targetSizeMM: CGSize,
        proportionsLocked: Bool,
        logicalScreenWidth: CGFloat,
        physicalScreenWidthMM: Double,
        previewZoom: Double = 1
    ) -> CGFloat {
        let mmPerPDFPoint = millimetersPerPDFPoint(
            pdfSizePoints: pdfSizePoints,
            targetSizeMM: targetSizeMM,
            proportionsLocked: proportionsLocked
        )
        let viewPointsPerMM = logicalPointsPerMillimeter(
            logicalScreenWidth: logicalScreenWidth,
            physicalScreenWidthMM: physicalScreenWidthMM
        )
        return mmPerPDFPoint * viewPointsPerMM * CGFloat(previewZoom)
    }
}

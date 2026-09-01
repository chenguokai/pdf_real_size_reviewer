import AppKit
import Combine
import PDFKit

struct PaperPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let portraitSizeMM: CGSize?

    static let pdf = PaperPreset(id: "pdf", title: "PDF’s own size", portraitSizeMM: nil)
    static let a0 = PaperPreset(id: "a0", title: "A0", portraitSizeMM: CGSize(width: 841, height: 1189))
    static let a1 = PaperPreset(id: "a1", title: "A1", portraitSizeMM: CGSize(width: 594, height: 841))
    static let a2 = PaperPreset(id: "a2", title: "A2", portraitSizeMM: CGSize(width: 420, height: 594))
    static let a3 = PaperPreset(id: "a3", title: "A3", portraitSizeMM: CGSize(width: 297, height: 420))
    static let a4 = PaperPreset(id: "a4", title: "A4", portraitSizeMM: CGSize(width: 210, height: 297))
    static let a5 = PaperPreset(id: "a5", title: "A5", portraitSizeMM: CGSize(width: 148, height: 210))
    static let letter = PaperPreset(id: "letter", title: "US Letter", portraitSizeMM: CGSize(width: 215.9, height: 279.4))
    static let presets: [PaperPreset] = [.pdf, .a0, .a1, .a2, .a3, .a4, .a5, .letter]

    func matches(_ sizeMM: CGSize, tolerance: CGFloat = 0.05) -> Bool {
        guard let portraitSizeMM else { return false }
        let portraitMatch = abs(sizeMM.width - portraitSizeMM.width) <= tolerance
            && abs(sizeMM.height - portraitSizeMM.height) <= tolerance
        let landscapeMatch = abs(sizeMM.width - portraitSizeMM.height) <= tolerance
            && abs(sizeMM.height - portraitSizeMM.width) <= tolerance
        return portraitMatch || landscapeMatch
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var fileURL: URL?
    @Published var pageIndex = 0
    @Published var targetWidthMM = 210.0
    @Published var targetHeightMM = 297.0
    @Published var proportionsLocked = true
    @Published var previewZoom = 1.0
    @Published var errorMessage: String?

    let calibration = DisplayCalibration()
    private var securityScopedURL: URL?

    var pageCount: Int { document?.pageCount ?? 0 }

    var currentPage: PDFPage? {
        guard let document, pageIndex >= 0, pageIndex < document.pageCount else { return nil }
        return document.page(at: pageIndex)
    }

    var pdfSizePoints: CGSize {
        currentPage?.bounds(for: .cropBox).size ?? .zero
    }

    var intrinsicSizeMM: CGSize {
        ScaleCalculator.intrinsicMillimeters(forPDFSize: pdfSizePoints)
    }

    var targetSizeMM: CGSize {
        CGSize(width: targetWidthMM, height: targetHeightMM)
    }

    var effectivePrintedSizeMM: CGSize {
        ScaleCalculator.effectivePrintedSize(
            pdfSizePoints: pdfSizePoints,
            targetSizeMM: targetSizeMM,
            proportionsLocked: proportionsLocked
        )
    }

    var pdfScaleFactor: CGFloat {
        ScaleCalculator.pdfViewScaleFactor(
            pdfSizePoints: pdfSizePoints,
            targetSizeMM: targetSizeMM,
            proportionsLocked: proportionsLocked,
            logicalScreenWidth: calibration.logicalSizePoints.width,
            physicalScreenWidthMM: calibration.effectivePhysicalWidthMM,
            previewZoom: previewZoom
        )
    }

    var printScalePercent: Double {
        let intrinsic = intrinsicSizeMM
        guard intrinsic.width > 0 else { return 0 }
        return Double(effectivePrintedSizeMM.width / intrinsic.width) * 100
    }

    var paperSizeTitle: String {
        let target = targetSizeMM
        let intrinsic = intrinsicSizeMM
        if proportionsLocked,
           abs(target.width - intrinsic.width) <= 0.05,
           abs(target.height - intrinsic.height) <= 0.05 {
            return PaperPreset.pdf.title
        }

        if let preset = PaperPreset.presets.dropFirst().first(where: { $0.matches(target) }) {
            return preset.title
        }

        return String(format: "Custom · %.1f × %.1f mm", target.width, target.height)
    }

    func isSelected(_ preset: PaperPreset) -> Bool {
        if preset.id == PaperPreset.pdf.id {
            return paperSizeTitle == PaperPreset.pdf.title
        }
        return preset.matches(targetSizeMM)
    }

    var title: String {
        fileURL?.lastPathComponent ?? "Real Size Previewer"
    }

    func choosePDF() {
        let panel = NSOpenPanel()
        panel.title = "Open a PDF"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.openPDF(at: url)
            }
        }
    }

    func openPDF(at url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else {
            errorMessage = "Please choose a PDF file."
            return
        }

        if let securityScopedURL {
            securityScopedURL.stopAccessingSecurityScopedResource()
        }
        let accessed = url.startAccessingSecurityScopedResource()

        guard let loadedDocument = PDFDocument(url: url), loadedDocument.pageCount > 0 else {
            if accessed { url.stopAccessingSecurityScopedResource() }
            errorMessage = "The selected PDF could not be opened."
            return
        }

        securityScopedURL = accessed ? url : nil
        document = loadedDocument
        fileURL = url
        pageIndex = 0
        previewZoom = 1
        resetToPDFSize()
    }

    func goToPage(_ index: Int) {
        guard pageCount > 0 else { return }
        pageIndex = min(max(index, 0), pageCount - 1)
        if proportionsLocked {
            updateHeightFromWidth()
        }
    }

    func setTargetWidth(_ value: Double) {
        targetWidthMM = max(value, 0.1)
        if proportionsLocked {
            updateHeightFromWidth()
        }
    }

    func setTargetHeight(_ value: Double) {
        targetHeightMM = max(value, 0.1)
        if proportionsLocked {
            let pageSize = pdfSizePoints
            guard pageSize.width > 0, pageSize.height > 0 else { return }
            targetWidthMM = targetHeightMM * pageSize.width / pageSize.height
        }
    }

    func setProportionsLocked(_ locked: Bool) {
        proportionsLocked = locked
        if locked { updateHeightFromWidth() }
    }

    func resetToPDFSize() {
        let size = intrinsicSizeMM
        guard size.width > 0, size.height > 0 else { return }
        proportionsLocked = true
        targetWidthMM = size.width
        targetHeightMM = size.height
    }

    func apply(_ preset: PaperPreset) {
        guard let portrait = preset.portraitSizeMM else {
            resetToPDFSize()
            return
        }

        let isLandscape = pdfSizePoints.width > pdfSizePoints.height
        targetWidthMM = isLandscape ? portrait.height : portrait.width
        targetHeightMM = isLandscape ? portrait.width : portrait.height

        let pageRatio = pdfSizePoints.width / max(pdfSizePoints.height, 0.01)
        let targetRatio = targetWidthMM / targetHeightMM
        proportionsLocked = abs(pageRatio - targetRatio) < 0.002
    }

    func setPreviewZoom(_ zoom: Double) {
        previewZoom = min(max(zoom, 0.1), 4)
    }

    private func updateHeightFromWidth() {
        let pageSize = pdfSizePoints
        guard pageSize.width > 0, pageSize.height > 0 else { return }
        targetHeightMM = targetWidthMM * pageSize.height / pageSize.width
    }
}

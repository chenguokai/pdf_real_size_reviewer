import PDFKit
import SwiftUI

struct PDFPreviewView: NSViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int
    let scaleFactor: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = false
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.displayBox = .cropBox
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        pdfView.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1)
        pdfView.minScaleFactor = 0.01
        pdfView.maxScaleFactor = 50
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
            context.coordinator.document = document
            context.coordinator.pageIndex = -1
        }

        if context.coordinator.pageIndex != pageIndex,
           let page = document.page(at: pageIndex) {
            pdfView.go(to: page)
            context.coordinator.pageIndex = pageIndex
        }

        guard scaleFactor.isFinite, scaleFactor > 0 else { return }
        if abs(pdfView.scaleFactor - scaleFactor) > 0.0001 {
            pdfView.scaleFactor = scaleFactor
        }
    }

    final class Coordinator {
        weak var document: PDFDocument?
        var pageIndex = -1
    }
}

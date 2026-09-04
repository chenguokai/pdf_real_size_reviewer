import PDFKit
import SwiftUI

struct PDFPreviewView: NSViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int
    let scaleFactor: CGFloat
    let onScaleFactorChange: (CGFloat) -> Void

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
        pdfView.minScaleFactor = 0.001
        pdfView.maxScaleFactor = 500
        context.coordinator.observeScaleChanges(in: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.onScaleFactorChange = onScaleFactorChange
        let documentChanged = pdfView.document !== document
        let viewportAnchor = documentChanged
            ? context.coordinator.captureViewport(in: pdfView)
            : nil

        context.coordinator.isApplyingModelState = true
        defer { context.coordinator.isApplyingModelState = false }

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
        context.coordinator.lastModelScaleFactor = scaleFactor
        if abs(pdfView.scaleFactor - scaleFactor) > 0.0001 {
            pdfView.scaleFactor = scaleFactor
        }

        if documentChanged, let viewportAnchor {
            context.coordinator.restoreViewport(
                viewportAnchor,
                in: pdfView,
                document: document,
                scaleFactor: scaleFactor
            )
        }
    }

    final class Coordinator {
        struct ViewportAnchor {
            let pageIndex: Int
            let normalizedPoint: CGPoint
        }

        weak var document: PDFDocument?
        var pageIndex = -1
        var onScaleFactorChange: ((CGFloat) -> Void)?
        var isApplyingModelState = false
        var lastModelScaleFactor: CGFloat = 0
        private var scaleObserver: NSObjectProtocol?

        func observeScaleChanges(in pdfView: PDFView) {
            scaleObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                guard let self, let pdfView, !self.isApplyingModelState else { return }
                let scale = pdfView.scaleFactor
                guard abs(scale - self.lastModelScaleFactor) > 0.0001 else { return }
                self.lastModelScaleFactor = scale
                self.onScaleFactorChange?(scale)
            }
        }

        func captureViewport(in pdfView: PDFView) -> ViewportAnchor? {
            guard let oldDocument = pdfView.document,
                  let documentView = pdfView.documentView else { return nil }

            let visibleCenterInDocument = CGPoint(
                x: documentView.visibleRect.midX,
                y: documentView.visibleRect.midY
            )
            let visibleCenterInPDFView = pdfView.convert(
                visibleCenterInDocument,
                from: documentView
            )
            guard let page = pdfView.page(for: visibleCenterInPDFView, nearest: true) else {
                return nil
            }

            let pageBounds = page.bounds(for: pdfView.displayBox)
            guard pageBounds.width > 0, pageBounds.height > 0 else { return nil }
            let pointOnPage = pdfView.convert(visibleCenterInPDFView, to: page)
            let normalizedPoint = CGPoint(
                x: (pointOnPage.x - pageBounds.minX) / pageBounds.width,
                y: (pointOnPage.y - pageBounds.minY) / pageBounds.height
            )
            return ViewportAnchor(
                pageIndex: oldDocument.index(for: page),
                normalizedPoint: normalizedPoint
            )
        }

        func restoreViewport(
            _ anchor: ViewportAnchor,
            in pdfView: PDFView,
            document: PDFDocument,
            scaleFactor: CGFloat
        ) {
            DispatchQueue.main.async { [weak pdfView, weak document] in
                guard let pdfView,
                      let document,
                      pdfView.document === document,
                      document.pageCount > 0 else { return }

                let restoredPageIndex = min(max(anchor.pageIndex, 0), document.pageCount - 1)
                guard let page = document.page(at: restoredPageIndex) else { return }

                pdfView.scaleFactor = scaleFactor
                pdfView.go(to: page)
                pdfView.layoutDocumentView()

                let pageBounds = page.bounds(for: pdfView.displayBox)
                let pointOnPage = CGPoint(
                    x: pageBounds.minX + anchor.normalizedPoint.x * pageBounds.width,
                    y: pageBounds.minY + anchor.normalizedPoint.y * pageBounds.height
                )
                guard let documentView = pdfView.documentView,
                      let scrollView = documentView.enclosingScrollView else { return }

                let pointInPDFView = pdfView.convert(pointOnPage, from: page)
                let pointInDocument = documentView.convert(pointInPDFView, from: pdfView)
                let clipView = scrollView.contentView
                let proposedBounds = CGRect(
                    x: pointInDocument.x - clipView.bounds.width / 2,
                    y: pointInDocument.y - clipView.bounds.height / 2,
                    width: clipView.bounds.width,
                    height: clipView.bounds.height
                )
                let constrainedBounds = clipView.constrainBoundsRect(proposedBounds)
                clipView.scroll(to: constrainedBounds.origin)
                scrollView.reflectScrolledClipView(clipView)
            }
        }

        deinit {
            if let scaleObserver {
                NotificationCenter.default.removeObserver(scaleObserver)
            }
        }
    }
}

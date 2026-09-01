import SwiftUI

@main
struct RealSizePreviewerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 980, minHeight: 680)
                .task {
                    openCommandLinePDFIfPresent()
                }
        }
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF…") {
                    model.choosePDF()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("Preview") {
                Button("Previous Page") {
                    model.goToPage(model.pageIndex - 1)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(model.pageIndex == 0)

                Button("Next Page") {
                    model.goToPage(model.pageIndex + 1)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(model.pageIndex + 1 >= model.pageCount)

                Divider()

                Button("Actual Size") {
                    model.setPreviewZoom(1)
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Zoom In") {
                    model.setPreviewZoom(model.previewZoom + 0.1)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    model.setPreviewZoom(model.previewZoom - 0.1)
                }
                .keyboardShortcut("-", modifiers: .command)
            }
        }
    }

    @MainActor
    private func openCommandLinePDFIfPresent() {
        guard model.document == nil else { return }
        let arguments = CommandLine.arguments.dropFirst()
        guard let path = arguments.first(where: { $0.lowercased().hasSuffix(".pdf") }) else { return }
        model.openPDF(at: URL(fileURLWithPath: path))
    }
}

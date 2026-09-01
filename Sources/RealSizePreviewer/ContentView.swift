import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var calibration: DisplayCalibration
    @State private var isDropTargeted = false

    init(model: AppModel) {
        self.model = model
        self.calibration = model.calibration
    }

    var body: some View {
        HSplitView {
            inspector
                .frame(minWidth: 294, idealWidth: 314, maxWidth: 350)

            previewArea
                .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(WindowScreenObserver { screen in
            calibration.update(for: screen)
        })
        .navigationTitle(model.title)
        .onOpenURL(perform: model.openPDF)
        .dropDestination(for: URL.self) { urls, _ in
            guard let pdf = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
                return false
            }
            model.openPDF(at: pdf)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .alert("Couldn’t Open PDF", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }

    private var inspector: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    appIdentity
                    fileSection
                    calibrationSection
                    printSection
                }
                .padding(18)
            }

            Divider()
            statusFooter
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var appIdentity: some View {
        HStack(spacing: 11) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.16), radius: 3, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text("Real Size")
                    .font(.title2.weight(.semibold))
                Text("Print preview, physically calibrated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fileSection: some View {
        InspectorSection(title: "PDF", symbol: "doc.richtext") {
            Button(action: model.choosePDF) {
                Label(model.document == nil ? "Open PDF…" : "Open Another PDF…", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)

            if let fileURL = model.fileURL {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(fileURL.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(model.pageCount) \(model.pageCount == 1 ? "page" : "pages")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var calibrationSection: some View {
        InspectorSection(title: "Display calibration", symbol: "display") {
            VStack(alignment: .leading, spacing: 3) {
                Text(calibration.displayName)
                    .font(.subheadline.weight(.medium))
                Text(displayTechnicalSummary)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Measure by", selection: $calibration.measurementMode) {
                ForEach(DisplayMeasurementMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if calibration.measurementMode == .measuredWidth {
                MeasurementField(
                    label: "Screen width",
                    value: $calibration.measuredWidthMM,
                    suffix: "mm"
                )
            } else {
                MeasurementField(
                    label: "Screen diagonal",
                    value: $calibration.diagonalInches,
                    suffix: "in"
                )
            }

            HStack {
                Text(calibration.calibrationSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if calibration.detectedPhysicalSizeMM.width > 0 {
                    Button("Use detected") { calibration.useDetectedSize() }
                        .font(.caption)
                        .buttonStyle(.link)
                }
            }

            Text("For best accuracy, measure the lit screen from left to right. macOS point and Retina pixel scaling is handled automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var printSection: some View {
        InspectorSection(title: "Printed size", symbol: "printer") {
            if model.document == nil {
                Text("Open a PDF to set its final printed dimensions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Menu {
                    ForEach(PaperPreset.presets) { preset in
                        Button { model.apply(preset) } label: {
                            if model.isSelected(preset) {
                                Label(preset.title, systemImage: "checkmark")
                            } else {
                                Text(preset.title)
                            }
                        }
                    }
                } label: {
                    Label(model.paperSizeTitle, systemImage: "rectangle.portrait")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                }

                MeasurementField(
                    label: "Width",
                    value: Binding(
                        get: { model.targetWidthMM },
                        set: model.setTargetWidth
                    ),
                    suffix: "mm"
                )

                MeasurementField(
                    label: "Height",
                    value: Binding(
                        get: { model.targetHeightMM },
                        set: model.setTargetHeight
                    ),
                    suffix: "mm"
                )

                Toggle("Lock PDF proportions", isOn: Binding(
                    get: { model.proportionsLocked },
                    set: model.setProportionsLocked
                ))

                if !model.proportionsLocked {
                    Label(
                        "The PDF is fitted proportionally inside the target sheet.",
                        systemImage: "arrow.down.right.and.arrow.up.left"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                metricRow("PDF page", value: millimeterString(model.intrinsicSizeMM))
                metricRow("Printed content", value: millimeterString(model.effectivePrintedSizeMM))
                metricRow("Print scaling", value: String(format: "%.1f%%", model.printScalePercent))
            }
        }
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Circle()
                    .fill(calibration.effectivePhysicalWidthMM > 0 ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text("Calibrated for \(calibration.displayName)")
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
            }
            Text("Move this window to another display to use that display’s calibration.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var previewArea: some View {
        VStack(spacing: 0) {
            previewToolbar
            Divider()

            ZStack {
                Color(nsColor: NSColor(calibratedWhite: 0.13, alpha: 1))

                if let document = model.document {
                    PDFPreviewView(
                        document: document,
                        pageIndex: model.pageIndex,
                        scaleFactor: model.pdfScaleFactor
                    )

                    VStack {
                        Spacer()
                        calibrationRuler
                            .padding(.bottom, 18)
                    }
                    .allowsHitTesting(false)
                } else {
                    emptyState
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.blue, style: StrokeStyle(lineWidth: 4, dash: [10]))
                        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                        .padding(24)
                    Label("Drop PDF to open", systemImage: "arrow.down.doc.fill")
                        .font(.title2.weight(.semibold))
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var previewToolbar: some View {
        HStack(spacing: 12) {
            if model.document != nil {
                Button { model.goToPage(model.pageIndex - 1) } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(model.pageIndex == 0)

                Text("Page \(model.pageIndex + 1) of \(model.pageCount)")
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 96)

                Button { model.goToPage(model.pageIndex + 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(model.pageIndex + 1 >= model.pageCount)

                Spacer()

                Button { model.setPreviewZoom(model.previewZoom - 0.1) } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Reduce preview zoom")

                Text("\(Int((model.previewZoom * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 44)

                Button { model.setPreviewZoom(model.previewZoom + 0.1) } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Increase preview zoom")

                Button("Actual size") { model.setPreviewZoom(1) }
                    .disabled(abs(model.previewZoom - 1) < 0.001)
                    .help("Return to the physically accurate 100% view")
            } else {
                Text("No PDF open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(.bar)
    }

    private var calibrationRuler: some View {
        VStack(spacing: 2) {
            PhysicalRuler(pointsPerMillimeter: calibration.pointsPerMillimeter)
            Text("10 cm calibration ruler")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 7)
        .padding(.bottom, 6)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(.white.opacity(0.8))
            Text("Preview a PDF at its real printed size")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("Open a PDF or drop one here. Calibrate the display, enter the intended print size, and the page will be shown at its physical size.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Button("Open PDF…", action: model.choosePDF)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(40)
    }

    private var displayTechnicalSummary: String {
        let logical = calibration.logicalSizePoints
        let pixels = calibration.pixelSize
        return "\(Int(logical.width))×\(Int(logical.height)) pt  •  \(Int(pixels.width))×\(Int(pixels.height)) px  •  \(String(format: "%.0f", calibration.backingScaleFactor))× backing"
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.caption)
    }

    private func millimeterString(_ size: CGSize) -> String {
        String(format: "%.1f × %.1f mm", size.width, size.height)
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct MeasurementField: View {
    let label: String
    @Binding var value: Double
    let suffix: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            TextField(label, value: $value, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 88)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
        }
        .font(.subheadline)
    }
}

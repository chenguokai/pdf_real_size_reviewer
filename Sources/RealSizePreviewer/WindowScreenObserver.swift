import AppKit
import SwiftUI

struct WindowScreenObserver: NSViewRepresentable {
    let onScreenChange: (NSScreen) -> Void

    func makeNSView(context: Context) -> ScreenObservingView {
        let view = ScreenObservingView()
        view.onScreenChange = onScreenChange
        return view
    }

    func updateNSView(_ view: ScreenObservingView, context: Context) {
        view.onScreenChange = onScreenChange
    }
}

final class ScreenObservingView: NSView {
    var onScreenChange: ((NSScreen) -> Void)?
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeObservers()

        guard let window else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.reportCurrentScreen()
        })
        observers.append(center.addObserver(
            forName: NSWindow.didChangeBackingPropertiesNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.reportCurrentScreen()
        })
        reportCurrentScreen()
    }

    func reportCurrentScreen() {
        guard let screen = window?.screen else { return }
        onScreenChange?(screen)
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    deinit {
        removeObservers()
    }
}

import AppKit
import SwiftUI

struct ToastView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 380, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(10)
    }
}

final class Toast {
    static let shared = Toast()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(symbol: String, title: String, message: String, screenFrame: CGRect) {
        hideWork?.cancel()
        panel?.orderOut(nil)

        let screen = NSScreen.screens.first { $0.frame == screenFrame } ?? NSScreen.main ?? NSScreen.screens[0]
        let host = NSHostingView(rootView: ToastView(symbol: symbol, title: title, message: message))
        let size = host.fittingSize

        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.contentView = host
        p.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2,
                                 y: screen.visibleFrame.minY + 16))
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; p.animator().alphaValue = 1 }
        panel = p

        let work = DispatchWorkItem { [weak self, weak p] in
            guard let p else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.4; p.animator().alphaValue = 0 },
                                                 completionHandler: { p.orderOut(nil); if self?.panel === p { self?.panel = nil } })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
}

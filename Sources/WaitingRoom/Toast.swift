import AppKit
import SwiftUI

enum ToastKind {
    case success, change, error

    var symbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .change: return "bell.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return .green
        case .change: return .orange
        case .error: return .red
        }
    }
}

struct ToastView: View {
    let kind: ToastKind
    let title: String
    let message: String
    let seconds: Double

    @State private var shown = false
    @State private var remaining: CGFloat = 1

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.title)
                .foregroundStyle(kind.tint)
                .symbolEffect(.bounce, value: shown)
                .scaleEffect(shown ? 1 : 0.3)
                .animation(.spring(response: 0.5, dampingFraction: 0.55), value: shown)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 15)
        .frame(width: 380, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .bottomLeading) {
            // The bar shows how long the toast has left.
            Capsule()
                .fill(kind.tint.opacity(0.7))
                .frame(height: 3)
                .scaleEffect(x: remaining, anchor: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .padding(10)
        .onAppear {
            shown = true
            withAnimation(.linear(duration: seconds)) { remaining = 0 }
        }
    }
}

final class Toast {
    static let shared = Toast()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private let seconds = 5.0

    func show(kind: ToastKind, title: String, message: String, screenFrame: CGRect) {
        hideWork?.cancel()
        panel?.orderOut(nil)

        let screen = NSScreen.screens.first { $0.frame == screenFrame } ?? NSScreen.main ?? NSScreen.screens[0]
        let host = NSHostingView(rootView: ToastView(kind: kind, title: title, message: message, seconds: seconds))
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

        let rest = NSRect(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.minY + 16,
                          width: size.width, height: size.height)
        p.setFrame(rest.offsetBy(dx: 0, dy: -40), display: false)
        p.alphaValue = 0
        p.orderFrontRegardless()
        // Rises into place with a slight overshoot.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.0, 0.3, 1.15)
            p.animator().setFrame(rest, display: true)
            p.animator().alphaValue = 1
        }
        panel = p

        let work = DispatchWorkItem { [weak self, weak p] in
            guard let p else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                p.animator().setFrame(p.frame.offsetBy(dx: 0, dy: -24), display: true)
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.orderOut(nil)
                if self?.panel === p { self?.panel = nil }
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

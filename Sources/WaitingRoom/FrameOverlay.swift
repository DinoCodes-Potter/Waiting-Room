import AppKit
import QuartzCore

/// Four corner brackets drawn around a watched region.
final class BracketView: NSView {
    var color: NSColor = .systemBlue {
        didSet { if color != oldValue { needsDisplay = true } }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds.insetBy(dx: 3, dy: 3)
        let len = max(6, min(20, min(b.width, b.height) / 3))
        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (b.minX, b.minY, 1, 1), (b.maxX, b.minY, -1, 1),
            (b.minX, b.maxY, 1, -1), (b.maxX, b.maxY, -1, -1),
        ]
        let path = NSBezierPath()
        path.lineWidth = 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        for (x, y, dx, dy) in corners {
            path.move(to: NSPoint(x: x + dx * len, y: y))
            path.line(to: NSPoint(x: x, y: y))
            path.line(to: NSPoint(x: x, y: y + dy * len))
        }
        color.setStroke()
        path.stroke()
    }

    func pulse(_ on: Bool) {
        wantsLayer = true
        guard let layer else { return }
        if on {
            if layer.animation(forKey: "pulse") == nil {
                let a = CABasicAnimation(keyPath: "opacity")
                a.fromValue = 1.0
                a.toValue = 0.3
                a.duration = 0.55
                a.autoreverses = true
                a.repeatCount = .infinity
                layer.add(a, forKey: "pulse")
            }
        } else {
            layer.removeAnimation(forKey: "pulse")
        }
    }
}

/// Click-through brackets drawn on screen around every watched region, so you can see what
/// Waiting Room is looking at. They pulse while the region changes and turn green when done.
final class FrameOverlays {
    private var items: [UUID: (panel: NSPanel, view: BracketView)] = [:]

    func hideAll() {
        for (_, item) in items { item.panel.orderOut(nil) }
    }

    func sync(_ watches: [Watch], enabled: Bool) {
        let alive = Set(watches.map { $0.id })
        for (id, item) in Array(items) where !alive.contains(id) {
            item.panel.orderOut(nil)
            items[id] = nil
        }
        guard enabled else { hideAll(); return }

        for w in watches {
            let recentlyDone = w.finishedAt.map { Date().timeIntervalSince($0) < 3 } ?? false
            guard let rect = w.liveRect, w.state != .finished || recentlyDone else {
                items[w.id]?.panel.orderOut(nil)
                continue
            }
            let frame = rect.insetBy(dx: -5, dy: -5)

            let color: NSColor
            if w.error != nil {
                color = .systemRed
            } else {
                switch w.state {
                case .finished: color = .systemGreen
                case .active: color = w.changing ? .systemOrange : .systemYellow
                case .armed: color = (w.mode == .every && w.changing) ? .systemOrange : .systemBlue
                }
            }

            if let item = items[w.id] {
                if item.panel.frame != frame { item.panel.setFrame(frame, display: true) }
                if !item.panel.isVisible { item.panel.orderFrontRegardless() }
                item.view.color = color
                item.view.pulse(w.changing)
            } else {
                let panel = NSPanel(contentRect: frame.insetBy(dx: -28, dy: -28),
                                    styleMask: [.borderless, .nonactivatingPanel],
                                    backing: .buffered, defer: false)
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                panel.ignoresMouseEvents = true
                panel.level = .floating
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
                let view = BracketView(frame: NSRect(origin: .zero, size: panel.frame.size))
                view.autoresizingMask = [.width, .height]
                view.color = color
                panel.contentView = view
                panel.alphaValue = 0
                panel.orderFrontRegardless()
                // The brackets snap in from slightly outside, like a camera finding focus.
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.4
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().setFrame(frame, display: true)
                    panel.animator().alphaValue = 1
                }
                items[w.id] = (panel, view)
            }
        }
    }
}

import AppKit
import SwiftUI

enum TriggerMode: String, CaseIterable, Identifiable {
    case stops = "Stops"
    case starts = "Starts"
    case every = "Any change"
    var id: String { rawValue }
}

enum Sensitivity: String, CaseIterable, Identifiable {
    case high = "High", medium = "Medium", low = "Low"
    var id: String { rawValue }

    var pixelDelta: Int {
        switch self {
        case .high: return 30
        case .medium: return 60
        case .low: return 100
        }
    }

    var minPixels: Int {
        switch self {
        case .high: return 4
        case .medium: return 16
        case .low: return 60
        }
    }
}

final class Watch: ObservableObject, Identifiable {
    enum State { case armed, active, finished }

    let id = UUID()
    let screenRect: CGRect
    let screenFrame: CGRect
    let displayID: CGDirectDisplayID
    let scale: CGFloat

    @Published var name: String
    @Published var mode: TriggerMode = .stops
    @Published var settle: Double = 8
    @Published var sensitivity: Sensitivity = .medium
    @Published var state: State = .armed
    @Published var changing = false
    @Published var summary = ""
    @Published var error: String?
    @Published var preview: NSImage?

    var nextDue = Date.distantPast

    private var prev1: [UInt32]?
    private var prev2: [UInt32]?
    private var ticks = 0
    private var changedTicks = 0
    private var lastChange = Date()
    private var lastFire = Date.distantPast
    private let everyCooldown: TimeInterval = 3

    init(name: String, screenRect: CGRect, screenFrame: CGRect, displayID: CGDirectDisplayID, scale: CGFloat) {
        self.name = name
        self.screenRect = screenRect
        self.screenFrame = screenFrame
        self.displayID = displayID
        self.scale = scale
    }

    var sourceRect: CGRect {
        CGRect(x: screenRect.minX - screenFrame.minX,
               y: screenFrame.maxY - screenRect.maxY,
               width: screenRect.width,
               height: screenRect.height)
    }

    var analysisSize: (width: Int, height: Int) {
        let s = min(1.0, 480.0 / max(screenRect.width, screenRect.height))
        return (max(8, Int(screenRect.width * s)), max(8, Int(screenRect.height * s)))
    }

    var pollInterval: TimeInterval {
        let base: TimeInterval = (mode == .stops && state == .armed) ? 2 : 1
        return ProcessInfo.processInfo.isLowPowerModeEnabled ? base * 2 : base
    }

    func reset() {
        state = .armed
        changing = false
        summary = ""
        prev1 = nil
        prev2 = nil
        ticks = 0
        changedTicks = 0
    }

    func ingest(_ image: CGImage) -> Bool {
        guard let cur = Watch.pixels(image) else { return false }
        ticks += 1
        if ticks % 3 == 1 {
            preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }

        let older = prev2
        let last = prev1
        prev2 = last
        prev1 = cur

        guard let a = last, a.count == cur.count else {
            prev2 = nil
            ticks = 1
            return false
        }
        guard ticks > 3, let b = older, b.count == cur.count else { return false }

        let delta = sensitivity.pixelDelta
        let needed = sensitivity.minPixels
        var n = 0
        cur.withUnsafeBufferPointer { c in
            a.withUnsafeBufferPointer { p1 in
                b.withUnsafeBufferPointer { p2 in
                    for i in 0..<c.count {
                        let x = c[i]
                        if x == p1[i] { continue }
                        if Watch.diff(x, p1[i]) > delta && Watch.diff(x, p2[i]) > delta {
                            n += 1
                            if n >= needed { break }
                        }
                    }
                }
            }
        }

        let isChanging = n >= needed
        if changing != isChanging { changing = isChanging }
        let now = Date()

        switch mode {
        case .stops:
            if isChanging {
                lastChange = now
                changedTicks += 1
                if state == .armed { state = .active }
            } else if state == .active, changedTicks >= 3,
                      now.timeIntervalSince(lastChange) >= settle {
                state = .finished
                return true
            }
        case .starts:
            if isChanging {
                state = .finished
                return true
            }
        case .every:
            if isChanging, now.timeIntervalSince(lastFire) >= everyCooldown {
                lastFire = now
                return true
            }
        }
        return false
    }

    @inline(__always)
    private static func diff(_ a: UInt32, _ b: UInt32) -> Int {
        let dr = Int(a & 0xFF) - Int(b & 0xFF)
        let dg = Int((a >> 8) & 0xFF) - Int((b >> 8) & 0xFF)
        let db = Int((a >> 16) & 0xFF) - Int((b >> 16) & 0xFF)
        return abs(dr) + abs(dg) + abs(db)
    }

    private static func pixels(_ image: CGImage) -> [UInt32]? {
        let w = image.width, h = image.height
        var buffer = [UInt32](repeating: 0, count: w * h)
        let ok = buffer.withUnsafeMutableBytes { ptr -> Bool in
            guard let ctx = CGContext(
                data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? buffer : nil
    }
}

import AppKit
import SwiftUI

enum TriggerMode: String, CaseIterable, Identifiable {
    case stops = "Stops"
    case starts = "Starts"
    case every = "Any change"
    case text = "Text"
    var id: String { rawValue }

    /// Short label for the segmented picker.
    var label: String { self == .every ? "Any" : rawValue }
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

/// One-tap settings for the things people usually wait for.
enum Preset: String, CaseIterable, Identifiable {
    case build = "Build"
    case download = "Download"
    case agent = "AI agent"
    var id: String { rawValue }

    var settle: Double {
        switch self {
        case .build: return 8
        case .download: return 4
        case .agent: return 15   // agents pause to think, so wait longer
        }
    }

    var sensitivity: Sensitivity {
        switch self {
        case .build: return .medium
        case .download: return .low
        case .agent: return .medium
        }
    }

    var symbol: String {
        switch self {
        case .build: return "hammer"
        case .download: return "arrow.down.circle"
        case .agent: return "sparkles"
        }
    }
}

final class Watch: ObservableObject, Identifiable {
    enum State { case armed, active, finished }

    /// The window that was under the selection when it was drawn. Capturing the window
    /// itself, instead of the screen, is what keeps a watch working while another window
    /// covers it.
    struct Target {
        let windowID: CGWindowID
        let app: String
        let title: String
        /// Region inside the window: points, origin top-left, relative to the window.
        let localRect: CGRect
        /// Size of the whole window in points when the watch was created.
        let windowSize: CGSize
    }

    let id = UUID()
    let screenRect: CGRect
    let screenFrame: CGRect
    let displayID: CGDirectDisplayID
    let scale: CGFloat
    let target: Target?

    @Published var name: String
    @Published var mode: TriggerMode = .stops
    @Published var settle: Double = 8
    @Published var sensitivity: Sensitivity = .medium
    @Published var followWindow = true
    @Published var phrase = ""
    @Published var state: State = .armed
    @Published var changing = false
    @Published var summary = ""
    @Published var error: String?
    @Published var preview: NSImage?
    /// 0...1 progress towards the "still for N seconds" alert.
    @Published var quiet: Double = 0
    /// Recent change intensity, newest last. Drives the live line in the menu.
    @Published var activity: [Double] = Array(repeating: 0, count: Watch.activityLength)
    /// Where the region is on screen right now (AppKit coordinates), nil when hidden.
    @Published var liveRect: CGRect?
    /// The window is on another Desktop (Space) or minimized, so macOS isn't drawing it
    /// and there is nothing to capture.
    @Published var hidden = false
    /// The window is on screen but captures come back blank.
    @Published var unreadable = false

    static let activityLength = 48

    var nextDue = Date.distantPast
    var windowSize: CGSize
    /// When the watch was created or last reset.
    private(set) var armedAt = Date()
    /// When activity first showed up in the region.
    private(set) var activeSince: Date?
    var finishedAt: Date?

    private var prev1: [UInt32]?
    private var prev2: [UInt32]?
    private var ticks = 0
    private var changedTicks = 0
    private var lastChange = Date()
    private var lastFire = Date.distantPast
    private var lastWasContent = false
    private var blankStreak = 0
    private let everyCooldown: TimeInterval = 3

    init(name: String, screenRect: CGRect, screenFrame: CGRect, displayID: CGDirectDisplayID,
         scale: CGFloat, target: Target?) {
        self.name = name
        self.screenRect = screenRect
        self.screenFrame = screenFrame
        self.displayID = displayID
        self.scale = scale
        self.target = target
        self.windowSize = target?.windowSize ?? .zero
    }

    var usesWindow: Bool { followWindow && target != nil }

    var regionSize: CGSize {
        if followWindow, let t = target { return t.localRect.size }
        return screenRect.size
    }

    /// Source rectangle for a whole-display capture (points, origin top-left).
    var sourceRect: CGRect {
        CGRect(x: screenRect.minX - screenFrame.minX,
               y: screenFrame.maxY - screenRect.maxY,
               width: screenRect.width,
               height: screenRect.height)
    }

    func size(maxSide: CGFloat, pixelScale: CGFloat = 1) -> (width: Int, height: Int) {
        let w = regionSize.width * pixelScale
        let h = regionSize.height * pixelScale
        let s = min(1.0, maxSide / max(w, h, 1))
        return (max(8, Int(w * s)), max(8, Int(h * s)))
    }

    var pollInterval: TimeInterval {
        let base: TimeInterval = ((mode == .stops && state == .armed) || mode == .text) ? 2 : 1
        return ProcessInfo.processInfo.isLowPowerModeEnabled ? base * 2 : base
    }

    /// How long the thing you were waiting for took: for "Stops", from the first activity to
    /// the last change; otherwise from when the watch started.
    var duration: TimeInterval? {
        switch mode {
        case .stops: return activeSince.map { max(0, lastChange.timeIntervalSince($0)) }
        case .starts, .text: return Date().timeIntervalSince(armedAt)
        case .every: return nil
        }
    }

    /// "45s", "12m 04s", "1h 03m".
    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(String(format: "%02d", s % 60))s" }
        return "\(s / 3600)h \(String(format: "%02d", (s % 3600) / 60))m"
    }

    func apply(_ preset: Preset) {
        settle = preset.settle
        sensitivity = preset.sensitivity
        mode = .stops
    }

    /// Forget previous frames after the window comes back, so the gap is never mistaken for a
    /// change. The "still for N seconds" clock restarts, so a job that finished while you
    /// were away is reported shortly after you return.
    func rebaseline() {
        prev1 = nil
        prev2 = nil
        ticks = 0
        lastWasContent = false
        blankStreak = 0
        lastChange = Date()
        quiet = 0
        changing = false
        unreadable = false
        error = nil
    }

    func reset() {
        state = .armed
        changing = false
        summary = ""
        quiet = 0
        finishedAt = nil
        armedAt = Date()
        activeSince = nil
        prev1 = nil
        prev2 = nil
        ticks = 0
        changedTicks = 0
    }

    private func record(_ value: Double) {
        activity.append(value)
        if activity.count > Watch.activityLength {
            activity.removeFirst(activity.count - Watch.activityLength)
        }
    }

    /// Checks OCR output for the phrase the user is waiting for.
    func ingestText(_ lines: [String]) -> Bool {
        let needle = phrase.trimmingCharacters(in: .whitespaces)
        guard mode == .text, !needle.isEmpty else { return false }
        let haystack = lines.joined(separator: " ")
        guard haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil else { return false }
        state = .finished
        return true
    }

    func ingest(_ image: CGImage) -> Bool {
        guard let cur = Watch.pixels(image) else { return false }

        // A window macOS isn't drawing comes back as a black picture. Treating that as a
        // real frame would look like the screen stopped changing, so skip it.
        let blank = !cur.contains { $0 & 0x00FF_FFFF != 0 }
        if usesWindow, blank, lastWasContent, blankStreak < 5 {
            blankStreak += 1
            if !unreadable { unreadable = true }
            return false
        }
        if !blank { blankStreak = 0 }
        lastWasContent = !blank
        if unreadable { unreadable = false }

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
            record(0)
            return false
        }
        guard ticks > 3, let b = older, b.count == cur.count else {
            record(0)
            return false
        }

        let delta = sensitivity.pixelDelta
        let needed = sensitivity.minPixels
        let cap = needed * 8
        var n = 0
        cur.withUnsafeBufferPointer { c in
            a.withUnsafeBufferPointer { p1 in
                b.withUnsafeBufferPointer { p2 in
                    for i in 0..<c.count {
                        let x = c[i]
                        if x == p1[i] { continue }
                        if Watch.diff(x, p1[i]) > delta && Watch.diff(x, p2[i]) > delta {
                            n += 1
                            if n >= cap { break }
                        }
                    }
                }
            }
        }

        let isChanging = n >= needed
        if changing != isChanging { changing = isChanging }
        record(min(1, Double(n) / Double(cap)))
        let now = Date()

        if mode == .stops, state == .active, !isChanging {
            quiet = min(1, now.timeIntervalSince(lastChange) / max(1, settle))
        } else if quiet != 0 {
            quiet = 0
        }

        switch mode {
        case .stops:
            if isChanging {
                lastChange = now
                changedTicks += 1
                if state == .armed { state = .active; activeSince = now }
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
        case .text:
            if state == .armed { state = .active; activeSince = now }
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

import AppKit
import SwiftUI
import Carbon.HIToolbox
import ScreenCaptureKit
import ServiceManagement
import UserNotifications

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let name: String
    let summary: String
}

final class WatchManager: ObservableObject {
    @Published var watches: [Watch] = []
    @Published var log: [LogEntry] = []
    @Published var permissionOK = CGPreflightScreenCaptureAccess()
    @Published var activeCount = 0
    @Published var iconFrame = 0
    @Published var userPaused = false
    @Published var launchAtLogin = false

    @Published var soundOn: Bool {
        didSet { UserDefaults.standard.set(soundOn, forKey: "soundOn") }
    }
    @Published var showFrames: Bool {
        didSet {
            UserDefaults.standard.set(showFrames, forKey: "showFrames")
            if !showFrames { frames.hideAll() }
        }
    }

    private let selector = RegionSelector()
    private let frames = FrameOverlays()
    private var hotKey: HotKey?
    private var timer: Timer?
    private var iconTimer: Timer?
    private var busy = false
    private var counter = 0

    private var cachedContent: SCShareableContent?
    private var cachedAt = Date.distantPast
    private var contentStale = true

    private var paused = false

    var canLaunchAtLogin: Bool { Bundle.main.bundleIdentifier != nil }

    /// Symbol for the menu bar. The hourglass turns over while something is being watched.
    var menuSymbol: String {
        if userPaused { return "pause.circle" }
        if activeCount > 0 {
            return ["hourglass.tophalf.filled", "hourglass", "hourglass.bottomhalf.filled"][iconFrame % 3]
        }
        return "hourglass.bottomhalf.filled"
    }

    init() {
        soundOn = UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true
        showFrames = UserDefaults.standard.object(forKey: "showFrames") as? Bool ?? true

        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }

        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.paused = true }
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.paused = false
                self?.contentStale = true
            }
        }

        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        t.tolerance = 0.25
        timer = t

        iconTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            guard let self, self.activeCount > 0, !self.userPaused else { return }
            self.iconFrame += 1
        }

        // Control-Option-W starts a selection from anywhere.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.addWatchBySelecting()
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        guard canLaunchAtLogin else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Adding and removing watches

    func addWatchBySelecting() {
        selector.begin { [weak self] rect in
            guard let self, let rect else { return }
            func area(_ r: CGRect) -> CGFloat { r.isNull ? 0 : r.width * r.height }
            guard let screen = NSScreen.screens.max(by: {
                      area(rect.intersection($0.frame)) < area(rect.intersection($1.frame))
                  }),
                  let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { return }
            let clipped = rect.intersection(screen.frame)
            guard !clipped.isNull, clipped.width > 8, clipped.height > 8 else { return }
            self.counter += 1
            let watch = Watch(name: "Watch \(self.counter)", screenRect: clipped, screenFrame: screen.frame,
                              displayID: displayID, scale: screen.backingScaleFactor,
                              target: self.detectWindow(for: clipped))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                self.watches.append(watch)
            }
            self.contentStale = true
        }
    }

    func remove(_ watch: Watch) {
        withAnimation(.easeOut(duration: 0.25)) {
            watches.removeAll { $0.id == watch.id }
        }
    }

    func requestPermission() {
        _ = CGRequestScreenCaptureAccess()
    }

    // MARK: - Finding the window under a selection

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    /// The frontmost window under the middle of the selection, which is the one the user was
    /// looking at when they drew the box.
    private func detectWindow(for rect: CGRect) -> Watch.Target? {
        let cgRect = CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
        let center = CGPoint(x: cgRect.midX, y: cgRect.midY)
        let me = Int(ProcessInfo.processInfo.processIdentifier)
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let infos = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []

        for info in infos {   // ordered front to back
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? Int, pid != me,
                  let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0.01,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  bounds.contains(center), bounds.width > 40, bounds.height > 40,
                  let number = info[kCGWindowNumber as String] as? Int
            else { continue }

            let local = cgRect.intersection(bounds).offsetBy(dx: -bounds.minX, dy: -bounds.minY)
            guard !local.isNull, local.width > 8, local.height > 8 else { return nil }
            return Watch.Target(windowID: CGWindowID(number),
                                app: info[kCGWindowOwnerName as String] as? String ?? "App",
                                title: info[kCGWindowName as String] as? String ?? "",
                                localRect: local,
                                windowSize: bounds.size)
        }
        return nil
    }

    /// Where a window is (CoreGraphics coordinates) and whether it is currently drawn on screen.
    /// A window on another Desktop or minimized has bounds but is not on screen.
    private func liveInfo(of id: CGWindowID) -> (bounds: CGRect, onScreen: Bool)? {
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let info = list.first,
              let dict = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary)
        else { return nil }
        return (bounds, info[kCGWindowIsOnscreen as String] as? Bool ?? false)
    }

    private func refreshLiveRects() {
        for w in watches {
            var rect: CGRect? = w.screenRect
            var nowHidden = false
            if w.usesWindow, let t = w.target {
                if let info = liveInfo(of: t.windowID) {
                    if info.bounds.size != w.windowSize { w.windowSize = info.bounds.size }
                    if info.onScreen {
                        rect = CGRect(x: info.bounds.minX + t.localRect.minX,
                                      y: primaryHeight - (info.bounds.minY + t.localRect.maxY),
                                      width: t.localRect.width, height: t.localRect.height)
                    } else {
                        rect = nil
                        nowHidden = true
                    }
                } else {
                    rect = nil
                    nowHidden = true
                }
            }
            if w.liveRect != rect { w.liveRect = rect }
            if w.hidden != nowHidden {
                // The capture path changes (screen capture <-> window server), so start the
                // comparison fresh instead of treating the switch as a change.
                w.hidden = nowHidden
                w.rebaseline()
            }
        }
        frames.sync(watches, enabled: showFrames)
    }

    // MARK: - Capture loop

    private func tick() {
        let ok = CGPreflightScreenCaptureAccess()
        if ok != permissionOK { permissionOK = ok }
        let active = watches.filter { $0.state == .active }.count
        if active != activeCount { activeCount = active }
        refreshLiveRects()

        guard !paused, !userPaused, !busy else { return }
        let now = Date()
        let due = watches.filter { $0.state != .finished && now >= $0.nextDue }
        guard !due.isEmpty else { return }
        busy = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.busy = false }

            if self.contentStale || self.cachedContent == nil || Date().timeIntervalSince(self.cachedAt) > 30 {
                // Include windows that are covered by others, which is the whole point.
                self.cachedContent = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                self.cachedAt = Date()
                self.contentStale = false
            }
            guard let content = self.cachedContent else {
                for w in due { w.error = "Can't read the screen. Grant Screen Recording access and relaunch." }
                return
            }

            for w in due where w.state != .finished {
                do {
                    guard let image = try await self.grab(w, content: content, maxSide: w.mode == .text ? 1400 : 480) else {
                        if w.hidden { w.unreadable = true }
                        w.nextDue = Date().addingTimeInterval(2)
                        continue
                    }
                    if w.error != nil { w.error = nil }
                    var fired = w.ingest(image)
                    var lines: [String]?
                    if w.mode == .text, !fired {
                        let found = await Task.detached(priority: .utility) { Analysis.recognizeLines(image) }.value
                        fired = w.ingestText(found)
                        if fired { lines = found }
                    }
                    w.nextDue = Date().addingTimeInterval(w.pollInterval - 0.2)
                    if fired {
                        w.finishedAt = Date()
                        await self.complete(w, content: content, lines: lines)
                    }
                } catch {
                    w.error = w.usesWindow
                        ? "Can't read that window. Is it minimized or on another Desktop?"
                        : "Capture failed. Check Screen Recording permission."
                    w.nextDue = Date().addingTimeInterval(2)
                    self.contentStale = true
                }
            }
        }
    }

    /// One capture of a watch's region. A window that is on another Desktop or minimized can't be
    /// seen by ScreenCaptureKit, so it is read from WindowServer directly instead.
    private func grab(_ w: Watch, content: SCShareableContent, maxSide: CGFloat,
                      pixelScale: CGFloat = 1) async throws -> CGImage? {
        if w.usesWindow, w.hidden, let t = w.target {
            guard let full = OffScreenCapture.image(of: t.windowID) else { return nil }
            return OffScreenCapture.region(full, local: t.localRect, windowSize: w.windowSize,
                                           output: w.size(maxSide: maxSide, pixelScale: pixelScale))
        }
        guard let plan = plan(for: w, content: content, maxSide: maxSide, pixelScale: pixelScale) else { return nil }
        return try await SCScreenshotManager.captureImage(contentFilter: plan.filter, configuration: plan.config)
    }

    /// Builds the filter and configuration for one capture. A window watch captures the window
    /// itself, so other windows in front of it don't matter.
    private func plan(for w: Watch, content: SCShareableContent, maxSide: CGFloat,
                      pixelScale: CGFloat = 1) -> (filter: SCContentFilter, config: SCStreamConfiguration)? {
        let size = w.size(maxSide: maxSide, pixelScale: pixelScale)
        let config = SCStreamConfiguration()
        config.width = size.width
        config.height = size.height
        config.showsCursor = false

        if w.usesWindow, let t = w.target {
            guard let window = content.windows.first(where: { $0.windowID == t.windowID }) else {
                w.error = "That window was closed."
                contentStale = true
                return nil
            }
            config.sourceRect = t.localRect.intersection(CGRect(origin: .zero, size: window.frame.size))
            config.ignoreShadowsSingleWindow = true
            return (SCContentFilter(desktopIndependentWindow: window), config)
        }

        guard let display = content.displays.first(where: { $0.displayID == w.displayID }) else {
            w.error = "That display is no longer connected."
            contentStale = true
            return nil
        }
        config.sourceRect = w.sourceRect
        return (makeFilter(display: display, content: content), config)
    }

    private func makeFilter(display: SCDisplay, content: SCShareableContent) -> SCContentFilter {
        let pid = ProcessInfo.processInfo.processIdentifier
        if let me = content.applications.first(where: { $0.processID == pid }) {
            return SCContentFilter(display: display, excludingApplications: [me], exceptingWindows: [])
        }
        return SCContentFilter(display: display, excludingWindows: [])
    }

    @MainActor
    private func complete(_ w: Watch, content: SCShareableContent, lines found: [String]?) async {
        var lines = found ?? []
        if found == nil, w.mode == .stops || w.mode == .starts,
           let image = (try? await grab(w, content: content, maxSide: 3000, pixelScale: w.scale)) ?? nil {
            lines = await Task.detached(priority: .userInitiated) { Analysis.recognizeLines(image) }.value
        }

        let summary = Analysis.summarize(lines, mode: w.mode, phrase: w.phrase)
        w.summary = summary
        log.insert(LogEntry(date: Date(), name: w.name, summary: summary), at: 0)
        if log.count > 8 { log.removeLast() }

        let title: String
        let kind: ToastKind
        switch w.mode {
        case .stops: title = "\(w.name): done"; kind = .success
        case .starts: title = "\(w.name): something changed"; kind = .change
        case .every: title = "\(w.name): screen changed"; kind = .change
        case .text: title = "\(w.name): found it"; kind = .success
        }
        let finalKind: ToastKind = summary.contains("⚠️") ? .error : kind

        if soundOn { NSSound(named: NSSound.Name("Glass"))?.play() }
        Toast.shared.show(kind: finalKind, title: title, message: summary, screenFrame: w.screenFrame)
        contentStale = true

        guard Bundle.main.bundleIdentifier != nil else { return }
        let note = UNMutableNotificationContent()
        note.title = title
        note.body = summary
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: note, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

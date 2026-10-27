import AppKit
import ScreenCaptureKit
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

    private let selector = RegionSelector()
    private var timer: Timer?
    private var busy = false
    private var counter = 0

    private var cachedContent: SCShareableContent?
    private var cachedAt = Date.distantPast
    private var contentStale = true

    private var paused = false

    init() {
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
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
    }

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
                              displayID: displayID, scale: screen.backingScaleFactor)
            self.watches.append(watch)
        }
    }

    func remove(_ watch: Watch) {
        watches.removeAll { $0.id == watch.id }
    }

    func requestPermission() {
        _ = CGRequestScreenCaptureAccess()
    }

    private func tick() {
        let ok = CGPreflightScreenCaptureAccess()
        if ok != permissionOK { permissionOK = ok }
        let active = watches.filter { $0.state == .active }.count
        if active != activeCount { activeCount = active }

        guard !paused, !busy else { return }
        let now = Date()
        let due = watches.filter { $0.state != .finished && now >= $0.nextDue }
        guard !due.isEmpty else { return }
        busy = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.busy = false }

            if self.contentStale || self.cachedContent == nil || Date().timeIntervalSince(self.cachedAt) > 30 {
                self.cachedContent = try? await SCShareableContent.current
                self.cachedAt = Date()
                self.contentStale = false
            }
            guard let content = self.cachedContent else {
                for w in due { w.error = "Can't read the screen. Grant Screen Recording access and relaunch." }
                return
            }

            for w in due where w.state != .finished {
                guard let display = content.displays.first(where: { $0.displayID == w.displayID }) else {
                    w.error = "That display is no longer connected."
                    self.contentStale = true
                    continue
                }
                let config = SCStreamConfiguration()
                config.sourceRect = w.sourceRect
                config.width = w.analysisSize.width
                config.height = w.analysisSize.height
                config.showsCursor = false
                let filter = self.makeFilter(display: display, content: content)
                do {
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    if w.error != nil { w.error = nil }
                    let fired = w.ingest(image)
                    w.nextDue = Date().addingTimeInterval(w.pollInterval - 0.2)
                    if fired { await self.complete(w, display: display, content: content) }
                } catch {
                    w.error = "Capture failed. Check Screen Recording permission."
                    self.contentStale = true
                }
            }
        }
    }

    private func makeFilter(display: SCDisplay, content: SCShareableContent) -> SCContentFilter {
        let pid = ProcessInfo.processInfo.processIdentifier
        if let me = content.applications.first(where: { $0.processID == pid }) {
            return SCContentFilter(display: display, excludingApplications: [me], exceptingWindows: [])
        }
        return SCContentFilter(display: display, excludingWindows: [])
    }

    @MainActor
    private func complete(_ w: Watch, display: SCDisplay, content: SCShareableContent) async {
        var lines: [String] = []
        if w.mode != .every {
            let config = SCStreamConfiguration()
            config.sourceRect = w.sourceRect
            config.width = max(8, Int(w.screenRect.width * w.scale))
            config.height = max(8, Int(w.screenRect.height * w.scale))
            config.showsCursor = false
            let filter = makeFilter(display: display, content: content)
            if let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) {
                lines = await Task.detached(priority: .userInitiated) { Analysis.recognizeLines(image) }.value
            }
        }

        let summary = Analysis.summarize(lines, mode: w.mode)
        w.summary = summary
        log.insert(LogEntry(date: Date(), name: w.name, summary: summary), at: 0)
        if log.count > 8 { log.removeLast() }

        let title: String
        var symbol: String
        switch w.mode {
        case .stops: title = "\(w.name): done"; symbol = "checkmark.circle.fill"
        case .starts: title = "\(w.name): something changed"; symbol = "bell.fill"
        case .every: title = "\(w.name): screen changed"; symbol = "bell.fill"
        }
        if summary.contains("⚠️") { symbol = "exclamationmark.triangle.fill" }

        NSSound(named: NSSound.Name("Glass"))?.play()
        Toast.shared.show(symbol: symbol, title: title, message: summary, screenFrame: w.screenFrame)
        contentStale = true

        guard Bundle.main.bundleIdentifier != nil else { return }
        let note = UNMutableNotificationContent()
        note.title = title
        note.body = summary
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: note, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

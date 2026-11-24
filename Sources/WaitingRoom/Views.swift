import SwiftUI

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct MenuView: View {
    @EnvironmentObject var manager: WatchManager
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Waiting Room").font(.headline)
                Spacer()
                Text(headerStatus)
                    .font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                if !manager.watches.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3)) { manager.userPaused.toggle() }
                    } label: {
                        Image(systemName: manager.userPaused ? "play.fill" : "pause.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.borderless)
                    .help(manager.userPaused ? "Resume watching" : "Pause all watches")
                }
            }

            if !manager.permissionOK {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Grant Screen Recording access…") { manager.requestPermission() }
                        .buttonStyle(.borderedProminent)
                    Text("After allowing it in System Settings, quit and reopen Waiting Room.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Button {
                manager.addWatchBySelecting()
            } label: {
                HStack {
                    Label("Watch a region…", systemImage: "viewfinder")
                    Spacer()
                    Text("⌃⌥W").font(.caption.monospaced()).opacity(0.7)
                }
            }
            .buttonStyle(.borderedProminent)

            if manager.watches.isEmpty {
                EmptyHint()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.watches) { w in
                            WatchCard(watch: w)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity),
                                    removal: .opacity.combined(with: .scale(scale: 0.95))))
                        }
                    }
                    .background(GeometryReader { g in
                        Color.clear.preference(key: HeightKey.self, value: g.size.height)
                    })
                }
                .frame(height: listHeight == 0 ? 160 : min(listHeight, 440))
                .onPreferenceChange(HeightKey.self) { listHeight = $0 }
            }

            if !manager.log.isEmpty {
                Divider()
                Text("Recent").font(.caption).foregroundStyle(.secondary)
                ForEach(manager.log.prefix(4)) { entry in
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(entry.name) · \(entry.date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(entry.summary).font(.caption).lineLimit(2)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Chime when done", isOn: $manager.soundOn)
                Toggle("Show frames on screen", isOn: $manager.showFrames)
                if manager.canLaunchAtLogin {
                    Toggle("Open at login", isOn: Binding(
                        get: { manager.launchAtLogin },
                        set: { manager.setLaunchAtLogin($0) }))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .font(.caption)

            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: manager.watches.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: manager.log.count)
    }

    private var headerStatus: String {
        if manager.userPaused { return "Paused" }
        return manager.watches.isEmpty ? "Nothing watched" : "\(manager.watches.count) watching"
    }
}

private struct EmptyHint: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
            Text("Drag a box around anything slow: a build log, a progress bar, an AI agent's output. It keeps watching even if another window covers it, and tells you when it stops.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

/// A dot that sends out rings while the region is changing.
struct PulseDot: View {
    let color: Color
    let active: Bool
    @State private var expand = false

    var body: some View {
        ZStack {
            if active {
                Circle()
                    .stroke(color.opacity(0.6), lineWidth: 2)
                    .frame(width: 8, height: 8)
                    .scaleEffect(expand ? 2.6 : 1)
                    .opacity(expand ? 0 : 1)
            }
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .frame(width: 18, height: 18)
        .onAppear { restart() }
        .onChange(of: active) { _, _ in restart() }
    }

    private func restart() {
        expand = false
        guard active else { return }
        withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) { expand = true }
    }
}

/// The heartbeat of the region: how much of it changed on each recent check.
struct ActivityLine: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            let step = w / CGFloat(max(1, values.count - 1))
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v) * (h - 3) - 1))
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.4), tint.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))
                Path { p in
                    for (i, v) in values.enumerated() {
                        let pt = CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v) * (h - 3) - 1)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 28)
        .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

/// Fills as the region stays quiet, so you can see how close the alert is.
struct QuietRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
        }
        .frame(width: 16, height: 16)
    }
}

struct WatchCard: View {
    @EnvironmentObject var manager: WatchManager
    @ObservedObject var watch: Watch

    private var statusText: String {
        if watch.state == .finished { return watch.summary }
        if watch.hidden { return "On another Desktop or minimized. Paused until it's back." }
        if watch.unreadable { return "Can't see that window right now. Holding the last frame." }
        if let e = watch.error { return e }
        switch watch.mode {
        case .text:
            let p = watch.phrase.trimmingCharacters(in: .whitespaces)
            return p.isEmpty ? "Type the text to wait for." : "Reading the region for “\(p)”…"
        case .stops:
            if watch.state == .armed { return "Waiting for activity to begin…" }
            return watch.changing ? "Changing now" : "Quiet. Alerting after \(Int(watch.settle))s of stillness"
        case .starts:
            return "Waiting for something to change…"
        case .every:
            return watch.changing ? "Changing now" : "Watching for any change…"
        }
    }

    private var dotColor: Color {
        if watch.hidden || watch.unreadable { return .gray }
        if watch.error != nil { return .red }
        switch watch.state {
        case .armed: return (watch.mode == .every && watch.changing) ? .orange : .blue
        case .active: return watch.changing ? .orange : .yellow
        case .finished: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                PulseDot(color: dotColor, active: watch.changing && watch.state != .finished)
                TextField("Name", text: $watch.name).textFieldStyle(.plain).fontWeight(.medium)
                Spacer()
                Button { manager.remove(watch) } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            if let target = watch.target {
                HStack(spacing: 6) {
                    Image(systemName: watch.followWindow ? "macwindow.badge.plus" : "display")
                        .foregroundStyle(watch.followWindow ? Color.accentColor : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                    Text(watch.followWindow
                         ? "\(target.app)\(target.title.isEmpty ? "" : " · \(target.title)")"
                         : "Whatever is on screen there")
                        .font(.caption).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 4)
                    Toggle("Follow window", isOn: $watch.followWindow)
                        .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                        .help("On: keeps watching this window even when another window covers it, and follows it if you move it.")
                }
            }

            if watch.hidden {
                Text("Tip: to keep watching across Desktops, right-click \(watch.target?.app ?? "the app") in the Dock, choose Options, then Assign To: All Desktops.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            if let img = watch.preview {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity)
                    .opacity(watch.hidden || watch.unreadable ? 0.35 : 1)
                    .overlay {
                        if watch.hidden || watch.unreadable {
                            Image(systemName: "rectangle.on.rectangle.slash")
                                .font(.title2).foregroundStyle(.secondary)
                        }
                    }
            }

            ActivityLine(values: watch.activity, tint: watch.state == .finished ? .green : .orange)

            HStack(spacing: 6) {
                if watch.state == .active, watch.mode == .stops, !watch.changing {
                    QuietRing(fraction: watch.quiet).transition(.scale.combined(with: .opacity))
                }
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }

            Picker("Alert me when it", selection: $watch.mode) {
                ForEach(TriggerMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if watch.mode == .text {
                TextField("Text to wait for, e.g. BUILD SUCCEEDED", text: $watch.phrase)
                    .textFieldStyle(.roundedBorder).font(.caption)
            }

            if watch.mode == .stops {
                Stepper("Settle time: \(Int(watch.settle))s", value: $watch.settle, in: 2...60, step: 1)
                    .font(.caption)
                HStack(spacing: 6) {
                    ForEach(Preset.allCases) { preset in
                        Button {
                            withAnimation(.spring(response: 0.3)) { watch.apply(preset) }
                        } label: {
                            Label(preset.rawValue, systemImage: preset.symbol).font(.caption2)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }

            HStack {
                Picker("Sensitivity", selection: $watch.sensitivity) {
                    ForEach(Sensitivity.allCases) { Text($0.rawValue).tag($0) }
                }
                .font(.caption)
                Spacer()
                if watch.state == .finished {
                    Button("Watch again") { withAnimation { watch.reset() } }.font(.caption)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(watch.state == .finished ? Color.green.opacity(0.8) : .clear, lineWidth: 2)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: watch.state)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: watch.mode)
        .animation(.easeInOut(duration: 0.2), value: watch.followWindow)
        .animation(.easeInOut(duration: 0.2), value: watch.hidden)
    }
}

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
                Text(manager.watches.isEmpty ? "Nothing watched" : "\(manager.watches.count) watching")
                    .font(.caption).foregroundStyle(.secondary)
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
                Label("Watch a region…", systemImage: "viewfinder")
            }
            .buttonStyle(.borderedProminent)

            if manager.watches.isEmpty {
                Text("Drag a box around anything that's slow: a build log, a progress bar, an AI agent's output. You'll get a notification when it stops changing.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.watches) { w in
                            WatchCard(watch: w)
                        }
                    }
                    .background(GeometryReader { g in
                        Color.clear.preference(key: HeightKey.self, value: g.size.height)
                    })
                }
                .frame(height: listHeight == 0 ? 160 : min(listHeight, 420))
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
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct WatchCard: View {
    @EnvironmentObject var manager: WatchManager
    @ObservedObject var watch: Watch

    private var statusText: String {
        if let e = watch.error { return e }
        switch watch.state {
        case .armed:
            switch watch.mode {
            case .stops: return "Waiting for activity to begin…"
            case .starts: return "Waiting for something to change…"
            case .every: return watch.changing ? "Changing now" : "Watching for any change…"
            }
        case .active:
            return watch.changing ? "Changing now" : "Quiet. Alerting after \(Int(watch.settle))s of stillness"
        case .finished:
            return watch.summary
        }
    }

    private var dotColor: Color {
        if watch.error != nil { return .red }
        switch watch.state {
        case .armed: return (watch.mode == .every && watch.changing) ? .orange : .gray
        case .active: return watch.changing ? .orange : .yellow
        case .finished: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                TextField("Name", text: $watch.name).textFieldStyle(.plain).fontWeight(.medium)
                Spacer()
                Button { manager.remove(watch) } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            if let img = watch.preview {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity)
            }

            Text(statusText).font(.caption).foregroundStyle(.secondary)

            Text("Chime and alert me when the region…").font(.caption2).foregroundStyle(.secondary)
            Picker("Alert me when it", selection: $watch.mode) {
                ForEach(TriggerMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if watch.mode == .stops {
                Stepper("Settle time: \(Int(watch.settle))s", value: $watch.settle, in: 2...60, step: 1)
                    .font(.caption)
            }

            HStack {
                Picker("Sensitivity", selection: $watch.sensitivity) {
                    ForEach(Sensitivity.allCases) { Text($0.rawValue).tag($0) }
                }
                .font(.caption)
                Spacer()
                if watch.state == .finished {
                    Button("Watch again") { watch.reset() }.font(.caption)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

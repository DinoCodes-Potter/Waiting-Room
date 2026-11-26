import CoreGraphics
import XCTest
@testable import WaitingRoom

final class WatchTests: XCTestCase {
    private let region = CGRect(x: 0, y: 0, width: 16, height: 16)

    private func makeWatch(mode: TriggerMode, window: Bool = false) -> Watch {
        let target = window
            ? Watch.Target(windowID: 1, app: "Test", title: "", localRect: region, windowSize: CGSize(width: 16, height: 16))
            : nil
        let w = Watch(name: "Test", screenRect: region, screenFrame: region, displayID: 0, scale: 1, target: target)
        w.mode = mode
        w.sensitivity = .high
        w.settle = 0
        return w
    }

    /// A flat 16x16 frame of one grey level.
    private func frame(_ gray: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        return ctx.makeImage()!
    }

    /// Three levels that all differ from each other, so every frame is a real change.
    private func moving(_ i: Int) -> CGImage { frame([0.2, 0.6, 1.0][i % 3]) }

    func testStopsFiresOnceActivityEnds() {
        let w = makeWatch(mode: .stops)
        for i in 0..<10 { XCTAssertFalse(w.ingest(moving(i))) }
        XCTAssertEqual(w.state, .active)
        var fired = false
        for _ in 0..<4 where !fired { fired = w.ingest(frame(0.5)) }
        XCTAssertTrue(fired)
        XCTAssertEqual(w.state, .finished)
    }

    func testStopsDoesNotFireWithoutAnyActivity() {
        let w = makeWatch(mode: .stops)
        for _ in 0..<12 { XCTAssertFalse(w.ingest(frame(0.5))) }
        XCTAssertEqual(w.state, .armed)
    }

    func testStartsFiresWhenSomethingChanges() {
        let w = makeWatch(mode: .starts)
        for _ in 0..<6 { XCTAssertFalse(w.ingest(frame(0.5))) }
        var fired = false
        for i in 0..<4 where !fired { fired = w.ingest(moving(i)) }
        XCTAssertTrue(fired)
    }

    func testBlankWindowFramesAreIgnored() {
        // A window macOS isn't drawing comes back black. That must not look like a change.
        let w = makeWatch(mode: .starts, window: true)
        for _ in 0..<6 { XCTAssertFalse(w.ingest(frame(0.5))) }
        for _ in 0..<3 { XCTAssertFalse(w.ingest(frame(0.0))) }
        XCTAssertTrue(w.unreadable)
        XCTAssertEqual(w.state, .armed)
        // Real content coming back clears the flag.
        XCTAssertFalse(w.ingest(frame(0.5)))
        XCTAssertFalse(w.unreadable)
    }

    func testRebaselineForgetsOldFrames() {
        let w = makeWatch(mode: .starts)
        for _ in 0..<6 { _ = w.ingest(frame(0.5)) }
        w.rebaseline()
        // The first frames after a rebaseline never count as a change, even if they differ.
        for i in 0..<3 { XCTAssertFalse(w.ingest(moving(i))) }
    }

    func testTextMatchIsCaseInsensitive() {
        let w = makeWatch(mode: .text)
        w.phrase = "build succeeded"
        XCTAssertFalse(w.ingestText(["Compiling…", "Linking"]))
        XCTAssertTrue(w.ingestText(["Compiling…", "** BUILD SUCCEEDED **"]))
        XCTAssertEqual(w.state, .finished)
    }

    func testEmptyPhraseNeverMatches() {
        let w = makeWatch(mode: .text)
        w.phrase = "   "
        XCTAssertFalse(w.ingestText(["anything"]))
    }

    func testDurationFormatting() {
        XCTAssertEqual(Watch.format(45), "45s")
        XCTAssertEqual(Watch.format(724), "12m 04s")
        XCTAssertEqual(Watch.format(3780), "1h 03m")
    }

    func testPresetsSetSettleAndSensitivity() {
        let w = makeWatch(mode: .starts)
        w.apply(.agent)
        XCTAssertEqual(w.mode, .stops)
        XCTAssertEqual(w.settle, Preset.agent.settle)
    }
}

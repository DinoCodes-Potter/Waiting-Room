import CoreGraphics
import Darwin
import Foundation

/// Reads a window's pixels while it is on another Desktop (Space) or minimized, where
/// ScreenCaptureKit only returns black. It uses the same WindowServer call that window
/// switchers use for their thumbnails. The call is private, so it is looked up at run time
/// and every failure degrades to "can't read it" rather than a crash.
enum OffScreenCapture {
    private typealias ConnectionFn = @convention(c) () -> Int32
    private typealias CaptureFn = @convention(c) (Int32, UnsafeMutablePointer<UInt32>, UInt32, UInt32) -> Unmanaged<CFArray>?

    private static let symbols: (connection: ConnectionFn, capture: CaptureFn)? = {
        let paths = [
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
        ]
        let pairs = [("SLSMainConnectionID", "SLSHWCaptureWindowList"),
                     ("CGSMainConnectionID", "CGSHWCaptureWindowList")]
        for path in paths {
            guard let lib = dlopen(path, RTLD_LAZY) else { continue }
            for (connName, capName) in pairs {
                if let c = dlsym(lib, connName), let f = dlsym(lib, capName) {
                    return (unsafeBitCast(c, to: ConnectionFn.self), unsafeBitCast(f, to: CaptureFn.self))
                }
            }
        }
        return nil
    }()

    static var isAvailable: Bool { symbols != nil }

    /// The whole window at its best resolution, or nil if macOS won't give it up.
    static func image(of windowID: CGWindowID) -> CGImage? {
        guard let symbols else { return nil }
        var id = windowID
        let bestResolution: UInt32 = 1 << 8
        let ignoreGlobalClipShape: UInt32 = 1 << 11
        guard let array = symbols.capture(symbols.connection(), &id, 1, bestResolution | ignoreGlobalClipShape)?
            .takeRetainedValue(),
              let first = (array as NSArray).firstObject,
              CFGetTypeID(first as CFTypeRef) == CGImage.typeID
        else { return nil }
        return (first as! CGImage)
    }

    /// Crops the watched region out of a whole-window image and scales it to `output`.
    /// `local` and `windowSize` are in points, origin top-left.
    static func region(_ full: CGImage, local: CGRect, windowSize: CGSize,
                       output: (width: Int, height: Int)) -> CGImage? {
        guard windowSize.width > 0, windowSize.height > 0 else { return nil }
        let sx = CGFloat(full.width) / windowSize.width
        let sy = CGFloat(full.height) / windowSize.height
        let pixels = CGRect(x: local.minX * sx, y: local.minY * sy,
                            width: local.width * sx, height: local.height * sy)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: full.width, height: full.height))
        guard !pixels.isNull, pixels.width >= 1, pixels.height >= 1,
              let cropped = full.cropping(to: pixels),
              let ctx = CGContext(data: nil, width: output.width, height: output.height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: output.width, height: output.height))
        return ctx.makeImage()
    }
}

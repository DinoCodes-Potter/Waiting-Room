// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WaitingRoom",
    platforms: [
        // ScreenCaptureKit's SCScreenshotManager requires macOS 14.
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "WaitingRoom",
            path: "Sources/WaitingRoom"
        ),
        .testTarget(
            name: "WaitingRoomTests",
            dependencies: ["WaitingRoom"],
            path: "Tests/WaitingRoomTests"
        ),
    ]
)

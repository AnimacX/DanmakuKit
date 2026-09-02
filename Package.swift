// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "DanmakuKit",
    platforms: [.iOS(.v13),.macOS(.v10_15)],
    products: [
        .library(name: "DanmakuKit", targets: ["DanmakuKit"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "DanmakuKit", dependencies:[]),
        .testTarget(name: "DanmakuKitTests", dependencies: ["DanmakuKit"])
    ],
    swiftLanguageModes: [.v5]
)


// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IkigaiKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IkigaiCore", targets: ["IkigaiCore"]),
    ],
    targets: [
        .target(name: "IkigaiCore"),
        .testTarget(name: "IkigaiCoreTests", dependencies: ["IkigaiCore"]),
    ]
)

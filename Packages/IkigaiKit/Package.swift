// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IkigaiKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IkigaiCore", targets: ["IkigaiCore"]),
        .library(name: "IkigaiRender", targets: ["IkigaiRender"]),
    ],
    targets: [
        .target(name: "IkigaiCore"),
        .target(name: "IkigaiRender", dependencies: ["IkigaiCore"]),
        .testTarget(name: "IkigaiCoreTests", dependencies: ["IkigaiCore"]),
    ]
)

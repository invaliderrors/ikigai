// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IkigaiKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IkigaiCore", targets: ["IkigaiCore"]),
        .library(name: "IkigaiRender", targets: ["IkigaiRender"]),
        .library(name: "IkigaiDesktop", targets: ["IkigaiDesktop"]),
    ],
    targets: [
        .target(name: "IkigaiCore"),
        .target(name: "IkigaiRender", dependencies: ["IkigaiCore"]),
        .target(name: "IkigaiDesktop", dependencies: ["IkigaiCore", "IkigaiRender"]),
        .testTarget(name: "IkigaiCoreTests", dependencies: ["IkigaiCore"]),
        .testTarget(name: "IkigaiDesktopTests", dependencies: ["IkigaiDesktop"]),
    ]
)

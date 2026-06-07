// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sadaa",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SadaaCore"),
        .executableTarget(name: "SadaaApp", dependencies: ["SadaaCore"]),
        .testTarget(name: "SadaaCoreTests", dependencies: ["SadaaCore"]),
    ]
)

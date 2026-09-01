// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StealthNotes",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "StealthNotes", path: "Sources/StealthNotes")
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Glance",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Glance",
            path: "Glance",
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)

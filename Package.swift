// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Chameo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Chameo", targets: ["Chameo"])
    ],
    targets: [
        .executableTarget(
            name: "Chameo",
            path: "Sources/Chameo",
            resources: [
                .copy("Resources/MenuBarIcons")
            ]
        ),
        .testTarget(
            name: "ChameoTests",
            dependencies: ["Chameo"],
            path: "Tests/ChameoTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)

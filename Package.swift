// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Chameo",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS("18.0")
    ],
    products: [
        .library(name: "ChameoCore", targets: ["ChameoCore"]),
        .executable(name: "Chameo", targets: ["Chameo"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.4"
        )
    ],
    targets: [
        .executableTarget(
            name: "Chameo",
            dependencies: [
                "ChameoCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Chameo",
            resources: [
                .copy("Resources/MenuBarIcons"),
                .copy("Resources/Onboarding"),
                .process("Resources/Localization")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "@executable_path/../Frameworks"
                ])
            ]
        ),
        .target(
            name: "ChameoCore",
            path: "Sources/ChameoCore"
        ),
        .testTarget(
            name: "ChameoCoreTests",
            dependencies: ["ChameoCore"],
            path: "Tests/ChameoCoreTests"
        ),
        .testTarget(
            name: "ChameoTests",
            dependencies: ["Chameo"],
            path: "Tests/ChameoTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)

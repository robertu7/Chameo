// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Chameo",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
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
        .testTarget(
            name: "ChameoTests",
            dependencies: ["Chameo"],
            path: "Tests/ChameoTests"
        )
    ],
    swiftLanguageModes: [.v5]
)

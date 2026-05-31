// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BitwardenBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BitwardenBar",
            targets: ["BitwardenBar"]
        ),
        .executable(
            name: "BitwardenBarStandalone",
            targets: ["BitwardenBarStandalone"]
        )
    ],
    dependencies: [
        // SQLite ORM for local vault cache
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "BitwardenBar",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/BitwardenBar",
            // Info.plist is managed by Xcode build settings (INFOPLIST_FILE),
            // not as a bundle resource — exclude it from SPM resource processing.
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "BitwardenBarStandalone",
            dependencies: ["BitwardenBar"],
            path: "Sources/BitwardenBarStandalone"
        ),
        .testTarget(
            name: "BitwardenBarTests",
            dependencies: ["BitwardenBar"],
            path: "Tests/BitwardenBarTests"
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ktalk",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ktalk", targets: ["ktalk"]),
        .library(name: "KTalkCore", targets: ["KTalkCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .systemLibrary(
            name: "CSQLCipher",
            pkgConfig: "sqlcipher",
            providers: [.brew(["sqlcipher"])]
        ),
        .target(
            name: "KTalkCore",
            dependencies: ["CSQLCipher"]
        ),
        .executableTarget(
            name: "ktalk",
            dependencies: [
                "KTalkCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "KTalkCoreTests",
            dependencies: [
                "KTalkCore",
                "ktalk",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)

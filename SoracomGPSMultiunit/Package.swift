// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoracomGPSMultiunit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "SoracomGPSMultiunitCore", targets: ["SoracomGPSMultiunitCore"]),
    ],
    targets: [
        // コアロジック (iOS/macOS で共通のビジネスロジック)
        .target(
            name: "SoracomGPSMultiunitCore",
            path: "Sources/SoracomGPSMultiunitCore"
        ),
        // ユニットテスト
        .testTarget(
            name: "SoracomGPSMultiunitCoreTests",
            dependencies: ["SoracomGPSMultiunitCore"],
            path: "Tests/SoracomGPSMultiunitCoreTests"
        )
    ]
)

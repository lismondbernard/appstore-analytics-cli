// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "appstore-analytics-cli",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "appstore-analytics",
            targets: ["AppStoreAnalyticsCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AppStoreAnalyticsCLI",
            dependencies: [
                .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk")
            ],
            path: "Sources/AppStoreAnalyticsCLI"
        )
    ]
)

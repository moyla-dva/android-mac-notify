// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AndroidMacNotifyMac",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "AndroidMacNotifyMac",
            targets: ["AndroidMacNotifyMac"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "AndroidMacNotifyMac",
            path: "Sources/AndroidMacNotifyMac"
        ),
        .testTarget(
            name: "AndroidMacNotifyMacTests",
            dependencies: ["AndroidMacNotifyMac"],
            path: "Tests/AndroidMacNotifyMacTests"
        ),
    ]
)

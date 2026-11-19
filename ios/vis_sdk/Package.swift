// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "vis_sdk",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "vis-sdk", targets: ["vis_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // The native Vis iOS SDK this plugin is built and tested against.
        .package(url: "https://github.com/revolution-uz/vis-sdk-ios", exact: "1.0.2"),
    ],
    targets: [
        .target(
            name: "vis_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "VisSDK", package: "vis-sdk-ios"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)

// swift-tools-version: 5.4

import PackageDescription

let package = Package(
    name: "CWriter",
    products: [
        .library(
            name: "CWriter",
            targets: ["CWriter"]
        )
    ],
    targets: [
        .target(
            name: "CWriter"
        ),
        .testTarget(
            name: "CWriterTests",
            dependencies: ["CWriter"]
        )
    ]
)

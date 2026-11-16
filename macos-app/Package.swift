// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HeadMotionMouse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HeadMotionMouseCore",
            targets: ["HeadMotionMouseCore"]
        ),
        .executable(
            name: "HeadMotionMouse",
            targets: ["HeadMotionMouse"]
        ),
        .executable(
            name: "HeadMotionMouseTestsRunner",
            targets: ["HeadMotionMouseTestsRunner"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HeadMotionMouseCore",
            dependencies: [],
            path: "Sources/HeadMotionMouseCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "HeadMotionMouse",
            dependencies: ["HeadMotionMouseCore"],
            path: "Sources/HeadMotionMouseApp",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "HeadMotionMouseTestsRunner",
            dependencies: ["HeadMotionMouseCore"],
            path: "TestsRunner",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "HeadMotionMouseTests",
            dependencies: ["HeadMotionMouseCore"],
            path: "Tests/HeadMotionMouseTests"
        )
    ]
)

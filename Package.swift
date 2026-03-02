// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlannerCapture",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PlannerCapture", targets: ["PlannerCapture"])
    ],
    targets: [
        .executableTarget(
            name: "PlannerCapture",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]
        ),
        .testTarget(
            name: "PlannerCaptureTests",
            dependencies: ["PlannerCapture"],
            path: "Tests/PlannerCaptureTests",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)

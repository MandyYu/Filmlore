// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StyleCamera",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StyleCameraCore",
            targets: ["StyleCameraCore"]
        ),
        .executable(
            name: "StyleCameraCoreChecks",
            targets: ["StyleCameraCoreChecks"]
        )
    ],
    targets: [
        .target(
            name: "StyleCameraCore"
        ),
        .executableTarget(
            name: "StyleCameraCoreChecks",
            dependencies: ["StyleCameraCore"]
        )
    ]
)

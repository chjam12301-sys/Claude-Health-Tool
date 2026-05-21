// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Claudoctor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Claudoctor",
            path: "Sources/Claudoctor"
        ),
        .testTarget(
            name: "ClaudoctorTests",
            dependencies: ["Claudoctor"],
            path: "Tests/ClaudoctorTests"
        )
    ]
)

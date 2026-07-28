// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlockHelm",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "BlockHelmDomain", targets: ["BlockHelmDomain"]),
        .library(name: "BlockHelmApplication", targets: ["BlockHelmApplication"]),
        .library(name: "BlockHelmInfrastructure", targets: ["BlockHelmInfrastructure"]),
        .executable(name: "BlockHelmApp", targets: ["BlockHelmApp"])
    ],
    targets: [
        .target(
            name: "BlockHelmDomain",
            path: "Sources/BlockHelmDomain"
        ),
        .target(
            name: "BlockHelmApplication",
            dependencies: ["BlockHelmDomain"],
            path: "Sources/BlockHelmApplication"
        ),
        .target(
            name: "BlockHelmInfrastructure",
            dependencies: ["BlockHelmDomain", "BlockHelmApplication"],
            path: "Sources/BlockHelmInfrastructure"
        ),
        .executableTarget(
            name: "BlockHelmApp",
            dependencies: [
                "BlockHelmDomain",
                "BlockHelmApplication",
                "BlockHelmInfrastructure"
            ],
            path: "Sources/BlockHelmApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BlockHelmDomainTests",
            dependencies: ["BlockHelmDomain"],
            path: "Tests/BlockHelmDomainTests"
        ),
        .testTarget(
            name: "BlockHelmInfrastructureTests",
            dependencies: ["BlockHelmInfrastructure", "BlockHelmDomain", "BlockHelmApplication"],
            path: "Tests/BlockHelmInfrastructureTests"
        )
    ]
)

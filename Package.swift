// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ShawnTile", platforms: [.macOS(.v13)], products: [
    .executable(name: "ShawnTile", targets: ["ShawnTile"])
], targets: [
    .target(name: "TileCore"),
    .executableTarget(name: "ShawnTile", dependencies: ["TileCore"]),
    .executableTarget(name: "TileCoreChecks", dependencies: ["TileCore"], path: "Tests/TileCoreTests")
])

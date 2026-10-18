// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Silverroom", platforms: [.macOS(.v14)], products: [.executable(name: "Silverroom", targets: ["Silverroom"])], targets: [.executableTarget(name: "Silverroom", resources: [.copy("Resources/romeling-logo.svg")]), .testTarget(name: "SilverroomTests", dependencies: ["Silverroom"])])

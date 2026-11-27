// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PendantKit",
  defaultLocalization: "en",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "PendantKit", targets: ["PendantKit"])
  ],
  targets: [
    .target(name: "PendantKit", resources: [.process("Resources")]),
    .testTarget(name: "PendantKitTests", dependencies: ["PendantKit"]),
  ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PendantKit",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "PendantKit", targets: ["PendantKit"])
  ],
  targets: [
    .target(name: "PendantKit"),
    .testTarget(name: "PendantKitTests", dependencies: ["PendantKit"]),
  ]
)

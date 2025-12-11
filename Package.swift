// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Tessera",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "Tessera",
      targets: ["Tessera"],
    ),
  ],
  targets: [
    .target(
      name: "Tessera",
    ),
    .testTarget(
      name: "TesseraTests",
      dependencies: ["Tessera"],
    ),
  ],
)

// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
    name: "FluentMongo",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FluentMongo",
            targets: ["FluentMongo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/OpenKitten/MongoKitten.git", .revision("master/5.0")),
        .package(url: "https://github.com/vapor/fluent.git", .revision("beta")),
    ],
    targets: [
        .target(
            name: "FluentMongo",
            dependencies: ["MongoKitten", "Fluent"]),
        .testTarget(
            name: "FluentMongoTests",
            dependencies: ["FluentMongo"]),
    ]
)

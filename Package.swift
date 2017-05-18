import PackageDescription

let package = Package(
    name: "MongoDriver",
    dependencies: [
        .Package(url: "https://github.com/vapor/fluent.git", majorVersion: 2),
        .Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 4),
    ]
)

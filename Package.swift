import PackageDescription

let package = Package(
    name: "FluentMongo",
    dependencies: [
        .Package(url: "https://github.com/vapor/fluent.git", Version(2,0,0, prereleaseIdentifiers: ["beta"])),
        .Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 4),
    ]
)

import PackageDescription

let package = Package(
    name: "FluentMongo",
    dependencies: [
    	.Package(url: "https://github.com/vapor/fluent.git", majorVersion: 1),
    	.Package(url: "https://github.com/OpenKitten/MongoKitten.git", "3.0.0-beta")
    ]
)

import PackageDescription

let package = Package(
    name: "FluentMongo",
    dependencies: [
    	.Package(url: "https://github.com/vapor/fluent.git", majorVersion: 0, minor: 10),
    	.Package(url: "//Users/paulrolfeIntrepid/Desktop/Projects/MongoKitten", majorVersion: 1, minor: 6)
    ]
)

import PackageDescription

let package = Package(
    name: "FluentMongo",
    dependencies: [
    	.Package(url: "https://github.com/qutheory/fluent.git", majorVersion: 0, minor: 3),
    	.Package(url: "https://github.com/PlanTeam/MongoKitten.git", majorVersion: 0, minor: 9)
    ]
)

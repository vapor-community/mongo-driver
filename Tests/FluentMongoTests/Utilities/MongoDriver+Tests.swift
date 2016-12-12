import FluentMongo
import Fluent

import XCTest

extension MongoDriver {
    static func makeTestConnection() -> MongoDriver {
        do {
            return try MongoDriver(connectionString: "mongodb://test:test@127.0.0.1:27017/test")
        } catch {
            print()
            print()
            print("⚠️ MongoDB Not Configured ⚠️")
            print()
            print("Error: \(error)")
            print()
            print("You must configure MongoDB to run with the following configuration: ")
            print("    database: 'test'")
            print("    user: 'test'")
            print("    password: 'test'")
            print("    host: 'localhost'")
            print("    port: '27017'")
            print()
            
            print()
            
            XCTFail("Configure MongoDB")
            fatalError("Configure MongoDB")
        }
    }
}

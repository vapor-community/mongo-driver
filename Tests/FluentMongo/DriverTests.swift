import XCTest

import Fluent
@testable import FluentMongo

/**
    To run these tests you must have `mongod`
    running with the following configuration.
 
    - user: test
    - password: test
    - localhost: test
    - port: 27017
*/
class DriverTests: XCTestCase {
    static var allTests : [(String, DriverTests -> () throws -> Void)] {
        return [
            ("testConnecting", testConnecting),
            ("testConnectFailing", testConnectFailing),
        ]
    }

    func testConnecting() {
        do {
            let _ = try MongoDriver(database: "test", user: "test", password: "test", host: "localhost", port: 27017)
        } catch {
            XCTFail("Failed to connect: \(error)")
        }
    }

    func testConnectFailing() {
        do {
            let _ = try MongoDriver(database: "test", user: "test", password: "test", host: "localhost", port: 500)
            XCTFail("Should not connect.")
        } catch {
            //
        }
    }

}
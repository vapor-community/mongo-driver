import XCTest

@testable import FluentMongo
import FluentTester

class DriverTests: XCTestCase {
    static var allTests : [(String, (DriverTests) -> () throws -> Void)] {
        return [
            ("testAll", testAll)
        ]
    }
    
    let driver: MongoDB = try! MongoDB("mongodb://localhost/fluent")
    
    func testAll() throws {
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testAll()
    }
}

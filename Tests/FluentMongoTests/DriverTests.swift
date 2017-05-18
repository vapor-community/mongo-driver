import XCTest

@testable import FluentMongo
import FluentTester

class DriverTests: XCTestCase {
    static var allTests : [(String, (DriverTests) -> () throws -> Void)] {
        return [
            ("testInsertAndFind", testInsertAndFind),
            ("testPivotsAndRelations", testPivotsAndRelations),
            ("testSchema", testSchema),
            ("testPaginate", testPaginate),
            ("testTimestamps", testTimestamps),
            ("testSoftDelete", testSoftDelete),
            ("testIndex", testIndex),
        ]
    }
    
    let driver: MongoDB = try! MongoDB("mongodb://localhost/fluent")
    
    func testInsertAndFind() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testInsertAndFind()
    }
    
    func testPivotsAndRelations() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testPivotsAndRelations()
    }
    
    func testSchema() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testSchema()
    }
    
    func testPaginate() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testPaginate()
    }
    
    func testTimestamps() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testTimestamps()
    }
    
    func testSoftDelete() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testSoftDelete()
    }
    
    func testIndex() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testIndex()
    }
}

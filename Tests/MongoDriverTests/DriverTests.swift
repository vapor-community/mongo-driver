import XCTest

@testable import MongoDriver
import FluentTester

class DriverTests: XCTestCase {
    static var allTests : [(String, (DriverTests) -> () throws -> Void)] {
        return [
            ("testInsertAndFind", testInsertAndFind),
            ("testArray", testArray),
            ("testPivotsAndRelations", testPivotsAndRelations),
            ("testSchema", testSchema),
            ("testPaginate", testPaginate),
            ("testTimestamps", testTimestamps),
            ("testSoftDelete", testSoftDelete),
            ("testIndex", testIndex),
            ("testSubset", testSubset),
        ]
    }
    
    let driver: MongoDB = try! MongoDB("mongodb://localhost/fluent")
    
    func testInsertAndFind() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testInsertAndFind()
    }
    
    // This test is for Mongo specific functionality.
    // It tests the ability to embed an array of documents in a document.
    func testArray() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        
        RecordStore.database = db
        
        let recordStore = RecordStore(
            vinyls: [
                Vinyl(name: "Thriller", year: 1982),
                Vinyl(name: "Back in Black", year: 1980),
                Vinyl(name: "The Dark Side of the Moon", year: 1973)
            ]
        )

        try recordStore.save()
        
        guard
            let foundStore = try RecordStore.makeQuery().all().first else {
                XCTFail()
                return
        }
        
        XCTAssert(foundStore.vinyls.count == 3)
        XCTAssert(foundStore.vinyls.filter({ return $0.name == "Thriller" }).count == 1)
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

    func testSubset() throws {
        try driver.drop()
        let db = Fluent.Database(driver)
        let tester = Tester(database: db)
        try tester.testSubset()
    }
}

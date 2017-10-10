import XCTest

@testable import MongoDriver
import FluentTester

class DriverTests: XCTestCase {
    static var allTests : [(String, (DriverTests) -> () throws -> Void)] {
        return [
            ("testInsertAndFind", testInsertAndFind),
            ("testArray", testArray),
            ("testSiblingsCount", testSiblingsCount),
            ("testMax", testMax),
            ("testSiblingsMax", testSiblingsMax),
            ("testMin", testMin),
            ("testSiblingsMin", testSiblingsMin),
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

    func testSiblingsCount() throws {
        try driver.drop()
        let db = Fluent.Database(driver)

        Pet.database = db
        Toy.database = db
        Pivot<Pet, Toy>.database = db

        let molly = Pet(name: "Molly", age: 2)
        let rex = Pet(name: "Rex", age: 1)

        try molly.save()
        try rex.save()

        let ball = Toy(name: "ball")
        let bone = Toy(name: "bone")
        let puppet = Toy(name: "puppet")

        try ball.save()
        try bone.save()
        try puppet.save()

        try molly.toys.add(ball)
        try molly.toys.add(puppet)

        try rex.toys.add(bone)

        XCTAssertEqual(try molly.toys.all().count, 2)
        XCTAssertEqual(try Toy.makeQuery().filter("name", .hasPrefix, "b").all().count, 2)
        XCTAssertEqual(try molly.toys.makeQuery().filter("name", .hasPrefix, "b").all().count, 1)
        XCTAssertEqual(try molly.toys.makeQuery().filter("name", .hasPrefix, "b").count(), 1)
        XCTAssertEqual(try molly.toys.count(), 2)
        XCTAssertEqual(try rex.toys.all().count, 1)
        XCTAssertEqual(try rex.toys.count(), 1)

        try puppet.pets.add(rex)

        XCTAssertEqual(try rex.toys.all().count, 2)
        XCTAssertEqual(try rex.toys.count(), 2)
    }

    func testMax() throws {

        try driver.drop()
        let db = Fluent.Database(driver)

        Pet.database = db

        let molly = Pet(name: "Molly", age: 2)
        let rex = Pet(name: "Rex", age: 1)
        let buddy = Pet(name: "Buddy", age: 6)

        try molly.save()
        try rex.save()
        try buddy.save()

        XCTAssertEqual(try Pet.makeQuery().aggregate("age", .max), 6)
    }

    func testSiblingsMax() throws {

        try driver.drop()
        let db = Fluent.Database(driver)

        Pet.database = db
        Toy.database = db
        Pivot<Pet, Toy>.database = db

        let molly = Pet(name: "Molly", age: 2)
        let rex = Pet(name: "Rex", age: 1)

        try molly.save()
        try rex.save()

        let ball = Toy(name: "ball")
        let bone = Toy(name: "bone")
        let puppet = Toy(name: "puppet")

        try ball.save()
        try bone.save()
        try puppet.save()

        try molly.toys.add(ball)
        try molly.toys.add(bone)
        try molly.toys.add(puppet)

        try rex.toys.add(bone)

        XCTAssertEqual(try bone.pets.makeQuery().aggregate("age", .max), 2)
    }

    func testMin() throws {

        try driver.drop()
        let db = Fluent.Database(driver)

        Pet.database = db

        let molly = Pet(name: "Molly", age: 2)
        let rex = Pet(name: "Rex", age: 1)
        let buddy = Pet(name: "Buddy", age: 6)

        try molly.save()
        try rex.save()
        try buddy.save()

        XCTAssertEqual(try Pet.makeQuery().aggregate("age", .max), 1)
    }

    func testSiblingsMin() throws {

        try driver.drop()
        let db = Fluent.Database(driver)

        Pet.database = db
        Toy.database = db
        Pivot<Pet, Toy>.database = db

        let molly = Pet(name: "Molly", age: 2)
        let rex = Pet(name: "Rex", age: 1)

        try molly.save()
        try rex.save()

        let ball = Toy(name: "ball")
        let bone = Toy(name: "bone")
        let puppet = Toy(name: "puppet")

        try ball.save()
        try bone.save()
        try puppet.save()

        try molly.toys.add(ball)
        try molly.toys.add(bone)
        try molly.toys.add(puppet)

        try rex.toys.add(bone)

        XCTAssertEqual(try bone.pets.makeQuery().aggregate("age", .max), 1)
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

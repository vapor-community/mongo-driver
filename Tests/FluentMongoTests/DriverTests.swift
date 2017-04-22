import XCTest

import Fluent
@testable import FluentMongo

/**
    To run these tests you must have `mongod`
    running with the following configuration.
 
    - user: test
    - password: test
    - host: localhost
    - port: 27017
*/
class DriverTests: XCTestCase {
    static var allTests : [(String, (DriverTests) -> () throws -> Void)] {
        return [
            ("testConnectFailing", testConnectFailing),
            ("testSaveClearFind", testSaveClearFind),
            ("testModify", testModify),
            ("testSelectLimit", testSelectLimit),
            ("testDeleteAll", testDeleteAll),
            ("testDeleteLimit0Implicit", testDeleteLimit0Implicit),
            ("testDeleteLimit0Explicit", testDeleteLimit0Explicit),
            ("testDeleteLimit1", testDeleteLimit1),
            ("testDeleteLimitInvalid", testDeleteLimitInvalid)
        ]
    }
    
    var database: Fluent.Database!
    var driver: MongoDriver!
    
    override func setUp() {
        driver = MongoDriver.makeTestConnection()
        database = Database(driver)
        clearUserCollection()
    }
    
    func clearUserCollection() {
        let _ = try? database.delete(User.self)
    }
    
    func createUser(suffix: String = "") -> User {
        let user = User(id: nil, name: "Vapor\(suffix)", email: "vapor@qutheory.io")
        User.database = database
        
        do {
            try user.save()
            print("JUST SAVED")
        } catch {
            XCTFail("Could not save: \(error)")
        }
        
        if user.id == .null {
            XCTFail("Primary key was null")
        }
        return user
    }

    func testConnectFailing() {
        do {
            let _ = try MongoDriver(database: "test", user: "test", password: "test", host: "localhost", port: 500)
            XCTFail("Should not connect.")
        } catch {
            // This should fail.
        }
    }
    
    func testSaveClearFind() {
        // Test inserting a record then dropping the collection
        let _ = createUser()
        var all = try? User.all()
        XCTAssert(all?.count == 1)
        clearUserCollection()
        all = try? User.all()
        XCTAssert(all?.count == 0)
        
        // Test finding record by id
        let user = createUser()
        do {
            let found = try User.find(user.id!)
            XCTAssertEqual(found?.id?.string, user.id?.string)
            XCTAssertEqual(found?.name, user.name)
            XCTAssertEqual(found?.email, user.email)
        } catch {
            XCTFail("Could not find user: \(error)")
        }
        
        do {
            let user = try User.find(2)
            XCTAssertNil(user)
        } catch {
            XCTFail("Could not find user: \(error)")
        }
    }

    func testModify() throws {
        User.database = database
        do {
            let user = User(id: nil, name: "Vapor", email: "mongo@vapor.codes")
            try user.save()

            guard let id = user.id else {
                XCTFail("No user id")
                return
            }

            guard let fetch = try User.find(id) else {
                XCTFail("Could not fetch user")
                return
            }

            XCTAssertEqual(fetch.name, user.name)

            fetch.name = "Vapor2"
            try fetch.save()

            guard let verify = try User.find(id) else {
                XCTFail("Could not fetch verify")
                return
            }
            XCTAssertEqual(fetch.name, verify.name)
        } catch {
            XCTFail("Could not modify: \(error)")
        }
    }
    
    func testSelectLimit() throws {
        // Insert dummy users Vapor0, Vapor1, ..., Vapor9
        for i in (0..<10) {
            _ = createUser(suffix: "\(i)")
        }
        
        let query = try User.makeQuery()
        try query.limit(3, offset: 2)
        // query.sorts = [Sort(User.self, "name", .ascending)]
        let result = try query.all()
        XCTAssertEqual(["Vapor2", "Vapor3", "Vapor4"], result.flatMap { $0.name })
    }

    func testSelectSortLimit() throws {
        // Insert dummy users Vapor9, Vapor8, ..., Vapor0
        for i in (0..<10).reversed() {
            _ = createUser(suffix: "\(i)")
        }
        
        let query = try User.makeQuery()
        try query.limit(3, offset: 2)
        try query.sort(Sort(User.self, "name", .ascending))
        let result = try query.all()
        XCTAssertEqual(["Vapor2", "Vapor3", "Vapor4"], result.flatMap { $0.name })
    }

    func testDeleteAll() throws {
        // Insert dummy users Vapor0, Vapor1, ..., Vapor9
        for i in (0..<10) {
            _ = createUser(suffix: "\(i)")
        }

        let query = try User.makeQuery()
        try query.delete()
        
        let remaining = try query.all()
        XCTAssertTrue(remaining.isEmpty)
    }
    
    func testDeleteLimit0Implicit() throws {
        // Insert dummy users Vapor0, Vapor1, Vapor0, ..., Vapor1
        for i in (0..<10) {
            _ = createUser(suffix: "\(i%2)")
        }
        
        let query = try User.makeQuery()
        try query.filter("name", "Vapor0")
        
        try query.delete()
        
        let remaining = try User.makeQuery().all()
        XCTAssertEqual(5, remaining.count)
        XCTAssertEqual(Array(repeating: "Vapor1", count: 5), remaining.flatMap { $0.name })
    }

    func testDeleteLimit0Explicit() throws {
        // Insert dummy users Vapor0, Vapor1, Vapor0, ..., Vapor1
        for i in (0..<10) {
            _ = createUser(suffix: "\(i%2)")
        }
        
        let query = try User.makeQuery()
        try query.filter("name", "Vapor0")
        try query.limit(0)
        try query.delete()
        
        let remaining = try User.makeQuery().all()
        XCTAssertEqual(5, remaining.count)
        XCTAssertEqual(Array(repeating: "Vapor1", count: 5), remaining.flatMap { $0.name })
    }

    func testDeleteLimit1() throws {
        // Insert dummy users Vapor0, Vapor1, Vapor0, ..., Vapor1
        for i in (0..<10) {
            _ = createUser(suffix: "\(i%2)")
        }
        
        let query = try User.makeQuery()
        try query.filter("name", "Vapor0")
        try query.limit(1)
        try query.delete()
        
        let remaining = try User.makeQuery().all()
        XCTAssertEqual(9, remaining.count)
    }

    func testDeleteLimitInvalid() throws {
        do {
            let query = try User.makeQuery()
            try query.limit(5)
            try query.delete()
            XCTFail("Limit greater than 1 should fail")
        } catch {
            // this should fail
        }
    }
}

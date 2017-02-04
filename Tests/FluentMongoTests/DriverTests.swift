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
            ("testDeleteLimitInvalid", testDeleteLimitInvalid),
            ("testCount", testCount),
            ("testGroupOr", testGroupOr),
            ("testGroupAnd", testGroupAnd),
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
        let _ = try? database.delete(User.entity)
    }
    
    func createUser(suffix: String = "") -> User {
        var user = User(id: nil, name: "Vapor\(suffix)", email: "vapor@qutheory.io")
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
            let _ = try MongoDriver(connectionString: "mongodb://test:test@localhost:500/test")
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
            var user = User(id: nil, name: "Vapor", email: "mongo@vapor.codes")
            try user.save()

            guard let id = user.id else {
                XCTFail("No user id")
                return
            }

            guard var fetch = try User.find(id) else {
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
        
        let query = try User.query()
        query.limit = Limit(count: 3, offset: 2)
        // query.sorts = [Sort(User.self, "name", .ascending)]
        let result = try query.all()
        XCTAssertEqual(["Vapor2", "Vapor3", "Vapor4"], result.map { $0.name })
    }

    func testSelectSortLimit() throws {
        // Insert dummy users Vapor9, Vapor8, ..., Vapor0
        for i in (0..<10).reversed() {
            _ = createUser(suffix: "\(i)")
        }
        
        let query = try User.query()
        query.limit = Limit(count: 3, offset: 2)
        query.sorts = [Sort(User.self, "name", .ascending)]
        let result = try query.all()
        XCTAssertEqual(["Vapor2", "Vapor3", "Vapor4"], result.map { $0.name })
    }

    func testDeleteAll() throws {
        // Insert dummy users Vapor0, Vapor1, ..., Vapor9
        for i in (0..<10) {
            _ = createUser(suffix: "\(i)")
        }

        let query = try User.query()
        try query.delete()
        
        let remaining = try query.all()
        XCTAssertTrue(remaining.isEmpty)
    }
    
    func testDeleteLimit0Implicit() throws {
        // Insert dummy users Vapor0, Vapor1, Vapor0, ..., Vapor1
        for i in (0..<10) {
            _ = createUser(suffix: "\(i%2)")
        }
        
        let query = try User.query()
        try query.filter("name", "Vapor0")
        
        try query.delete()
        
        let remaining = try User.query().all()
        XCTAssertEqual(5, remaining.count)
        XCTAssertEqual(Array(repeating: "Vapor1", count: 5), remaining.map { $0.name })
    }

    func testDeleteLimit0Explicit() throws {
        // Insert dummy users Vapor0, Vapor1, Vapor0, ..., Vapor1
        for i in (0..<10) {
            _ = createUser(suffix: "\(i%2)")
        }
        
        let query = try User.query()
        try query.filter("name", "Vapor0")
        query.limit = Limit(count: 0)
        try query.delete()
        
        let remaining = try User.query().all()
        XCTAssertEqual(5, remaining.count)
        XCTAssertEqual(Array(repeating: "Vapor1", count: 5), remaining.map { $0.name })
    }

    func testDeleteLimit1() throws {
        // Insert dummy users Vapor0, Vapor1, Vapor0, ..., Vapor1
        for i in (0..<10) {
            _ = createUser(suffix: "\(i%2)")
        }
        
        let query = try User.query()
        try query.filter("name", "Vapor0")
        query.limit = Limit(count: 1)
        try query.delete()
        
        let remaining = try User.query().all()
        XCTAssertEqual(9, remaining.count)
    }

    func testDeleteLimitInvalid() throws {
        do {
            let query = try User.query()
            query.limit = Limit(count: 5)
            try query.delete()
            XCTFail("Limit greater than 1 should fail")
        } catch {
            // this should fail
        }
    }
    
    func testCount() throws {
        // Insert dummy users Vapor0, Vapor1, Vapor0, ..., Vapor1
        for i in (0..<10) {
            _ = createUser(suffix: "\(i%2)")
        }
        let count = try User.query().count()
        XCTAssertEqual(10, count)
    }
    
    func testGroupOr() throws {
        // Insert dummy users Vapor0, Vapor1, ...
        for i in (0..<10) {
            _ = createUser(suffix: "\(i)")
        }
        
        let query = try User.query().or({ query in
            try query.filter("name", "Vapor3")
            try query.filter("name", "Vapor4")
            try query.filter("name", "Vapor5")
            try query.filter("name", "Vapor6")
            try query.filter("name", "Vapor7")
        })
        query.limit = Limit(count: 3, offset: 1)
        let result = try query.all()
        XCTAssertEqual(["Vapor4", "Vapor5", "Vapor6"], result.map { $0.name })
    }
    
    func testGroupAnd() throws {
        // Insert dummy users Vapor0, Vapor1, ...
        for i in (0..<10) {
            var user = createUser(suffix: "\(i)")
            if i%2 == 0 {
                user.email = "test@test.com"
                try user.save()
            }
        }
        
        let query = try User.query()
            .or{ query in
                try query.filter("name", "Vapor1")
                try query.and{ query in
                    try query.filter("name", "Vapor2")
                    try query.filter("email", "test@test.com")
                }
                try query.and{ query in
                    try query.filter("name", "Vapor3")
                    try query.filter("email", "test@test.com")
                }
                try query.filter("name", "Vapor4")
                try query.filter("name", "Vapor5")
            }
        query.limit = Limit(count: 2, offset: 1)
        let result = try query.all()
        XCTAssertEqual(["Vapor2", "Vapor4"], result.map { $0.name })
    }
}

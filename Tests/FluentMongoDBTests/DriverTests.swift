import Async
import XCTest
import Dispatch
import FluentMongo

class FluentMongoTests: XCTestCase {
    var db: DatabaseConnectionPool<MongoDB>!
    let loop = DispatchEventLoop(label: "test")
    
    override func setUp() {Let
        self.db = MongoDB(database: "test").makeConnectionPool(max: 20, using: "mongodb://localhost:27017", on: loop)
        _ = try? self.db.requestConnection().flatMap(to: Void.self) { conn in
            return try conn["test"].drop()
        }.blockingAwait()
    }
    
    func testModels() throws {
        try benchmarkModels().blockingAwait(timeout: .seconds(60))
    }
//
//    func testTimestampable() throws {
//        try benchmarker.benchmarkTimestampable().blockingAwait(timeout: .seconds(60))
//    }
//
//    func testChunking() throws {
//        try benchmarker.benchmarkChunking().blockingAwait(timeout: .seconds(60))
//    } d
//
    static let allTests = [
        ("testModels", testModels),
//        ("testTimestampable", testTimestampable),
//        ("testChunking", testChunking),
    ]
    
    /// The actual benchmark.
    func _benchmarkModels(on conn: MongoDB.Connection) throws -> Future<Void> {
        // create
        let a = Foo(bar: "asdf", baz: 42)
        let b = Foo(bar: "asdf", baz: 42)
        
        return a.save(on: conn).flatMap(to: Void.self) {
            return b.save(on: conn)
        }.flatMap(to: Int.self) {
            return conn.query(Foo.self).count()
        }.flatMap(to: Void.self) { count in
            XCTAssertEqual(count, 2)
            
            // update
            b.bar = "fdsa"
            
            return b.save(on: conn)
        }.flatMap(to: Foo?.self) {
            return try Foo.find(b.requireID(), on: conn)
        }.flatMap(to: Void.self) { fetched in
            XCTAssertEqual(fetched?.bar, "fdsa")
            
            return b.delete(on: conn)
        }.flatMap(to: Int.self) {
            return conn.query(Foo.self).count()
        }.map(to: Void.self) { count in
            XCTAssertEqual(count, 1)
        }
    }
    
    /// Benchmark the basic model CRUD.
    public func benchmarkModels() throws -> Future<Void> {
        return db.requestConnection().flatMap(to: Void.self) { conn in
            return try self._benchmarkModels(on: conn).map(to: Void.self) {_ in 
                self.db.releaseConnection(conn)
            }
        }
    }
}

final class Foo: Model {
    /// See Model.Database
    typealias Database = MongoDB
    
    /// See Model.ID
    typealias ID = ObjectId
    
    /// See Model.name
    static var name: String { return "foo" }
    
    /// See Model.idKey
    static var idKey: IDKey { return \._id }
    
    /// See Model.database
    public static var database: DatabaseIdentifier<MongoDB> {
        return .init("test")
    }
    
    /// Foo's identifier
    var _id: ObjectId? = ObjectId()
    
    /// Test string
    var bar: String
    
    /// Test integer
    var baz: Int
    
    /// Create a new foo
    init(id: ObjectId? = nil, bar: String, baz: Int) {
        self._id = id
        self.bar = bar
        self.baz = baz
    }
}

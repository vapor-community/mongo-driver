import XCTest

@testable import FluentMongo

class DriverTests: XCTestCase {
    static var allTests : [(String, (DriverTests) -> () throws -> Void)] {
        return [
            
        ]
    }
    
    var database: MongoDB!
    
    override func setUp() {
        database = try! MongoDB("mongodb://localhost/fluent")
    }
    
    
}

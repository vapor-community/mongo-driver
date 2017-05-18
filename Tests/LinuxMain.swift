#if os(Linux)

import XCTest
@testable import MongoDriverTests

XCTMain([
    testCase(DriverTests.allTests),
])

#endif
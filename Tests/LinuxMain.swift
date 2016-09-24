#if os(Linux)

import XCTest
@testable import FluentMongoTests

XCTMain([
    testCase(DriverTests.allTests),
])

#endif
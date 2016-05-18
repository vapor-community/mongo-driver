#if os(Linux)

import XCTest
@testable import FluentMongoTestSuite

XCTMain([
    testCase(DriverTests.allTests),
])

#endif
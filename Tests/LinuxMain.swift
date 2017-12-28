#if os(Linux)

import XCTest
@testable import FluentMongoDBTests

XCTMain([
    testCase(FluentMongoDBTests.allTests),
])

#endif

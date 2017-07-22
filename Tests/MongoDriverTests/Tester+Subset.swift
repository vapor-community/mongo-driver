import FluentTester

extension Tester {
    public func testSubset() throws {
        Compound.database = database
        try Compound.prepare(database)
        defer {
            try! Compound.revert(database)
        }

        var compounds: [Compound] = []
        for i in 0..<4 {
            let compound = Compound(name: "Test \(i)")
            try compound.save()
            compounds.append(compound)
        }

        let firstTwoCompounds = Array(compounds[0..<2])
        let firstTwoNames = firstTwoCompounds.map { $0.name.makeNode() }

        let inQuery = try Compound.makeQuery().filter(.subset("name", .in, firstTwoNames))
        try testEquals(firstTwoCompounds, try inQuery.all())

        let notInQuery = try Compound.makeQuery().filter(.subset("name", .notIn, firstTwoNames))
        try testEquals(Array(compounds[2..<4]), try notInQuery.all())
    }
}

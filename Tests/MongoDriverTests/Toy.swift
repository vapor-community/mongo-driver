//
//  Toy.swift
//  MongoDriver
//
//  Created by Valerio Mazzeo on 05/10/2017.
//

import Foundation
import Fluent

final class Toy: Entity {

    public let name: String

    public init(name: String) {
        self.name = name
    }

    // MARK: Storable

    public let storage = Storage()

    // MARK: RowConvertible

    public convenience init(row: Row) throws {

        self.init(name: try row.get("name"))
    }

    public func makeRow() throws -> Row {

        var row = Row()

        try row.set(Toy.idKey, self.id)
        try row.set("name", self.name)

        return row
    }
}

// MARK: - Relationships

extension Toy {

    public var pets: Siblings<Toy, Pet, Pivot<Toy, Pet>> {
        return self.siblings()
    }
}

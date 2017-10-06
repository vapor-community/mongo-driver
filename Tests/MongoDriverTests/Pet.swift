//
//  Pet.swift
//  MongoDriver
//
//  Created by Valerio Mazzeo on 05/10/2017.
//

import Foundation
import Fluent

final class Pet: Entity {

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

        try row.set(Pet.idKey, self.id)
        try row.set("name", self.name)

        return row
    }
}

// MARK: - Relationships

extension Pet {

    public var toys: Siblings<Pet, Toy, Pivot<Pet, Toy>> {
        return self.siblings()
    }
}


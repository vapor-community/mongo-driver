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

    public let age: Int

    public var favoriteToyId: Identifier?

    public init(name: String, age: Int, favoriteToyId: Identifier? = nil) {
        self.name = name
        self.age = age
        self.favoriteToyId = favoriteToyId
    }

    // MARK: Storable

    public let storage = Storage()

    // MARK: RowConvertible

    public convenience init(row: Row) throws {

        self.init(
            name: try row.get("name"),
            age: try row.get("age"),
            favoriteToyId: try row.get("favoriteToyId")
        )
    }

    public func makeRow() throws -> Row {

        var row = Row()

        try row.set(Pet.idKey, self.id)
        try row.set("name", self.name)
        try row.set("age", self.age)
        try row.set("favoriteToyId", self.favoriteToyId)

        return row
    }
}

// MARK: - Relationships

extension Pet {

    public var favoriteToy: Parent<Pet, Toy> {
        return self.parent(id: self.favoriteToyId)
    }

    public var toys: Siblings<Pet, Toy, Pivot<Pet, Toy>> {
        return self.siblings()
    }
}


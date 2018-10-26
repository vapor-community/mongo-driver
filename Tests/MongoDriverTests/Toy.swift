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

    public let material: String?

    public init(name: String, material: String? = nil) {
        self.name = name
        self.material = material
    }

    // MARK: Storable

    public let storage = Storage()

    // MARK: RowConvertible

    public convenience init(row: Row) throws {

        self.init(
            name: try row.get("name"),
            material: try? row.get("material")
        )
    }

    public func makeRow() throws -> Row {

        var row = Row()

        try row.set(Toy.idKey, self.id)
        try row.set("name", self.name)

        if let material = self.material {
            try row.set("material", material)
        }

        return row
    }
}

// MARK: - Relationships

extension Toy {

    public var pets: Siblings<Toy, Pet, Pivot<Toy, Pet>> {
        return self.siblings()
    }
}

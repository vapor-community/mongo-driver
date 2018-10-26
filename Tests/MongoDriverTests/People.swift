//
//  People.swift
//  MongoDriverTests
//
//  Created by Valerio Mazzeo on 25/10/2018.
//

import Foundation
import Fluent

final class Adult: Entity {

    public let name: String

    public init(name: String) {
        self.name = name
    }

    // MARK: Storable

    public let storage = Storage()

    // MARK: RowConvertible

    public convenience init(row: Row) throws {

        self.init(
            name: try row.get("name")
        )
    }

    public func makeRow() throws -> Row {

        var row = Row()

        try row.set(Adult.idKey, self.id)
        try row.set("name", self.name)

        return row
    }
}

final class Child: Entity {

    public let name: String

    public var age: Int

    public var parentId: Identifier

    public init(name: String, age: Int, parentId: Identifier) {
        self.name = name
        self.age = age
        self.parentId = parentId
    }

    // MARK: Storable

    public let storage = Storage()

    // MARK: RowConvertible

    public convenience init(row: Row) throws {

        self.init(
            name: try row.get("name"),
            age: try row.get("age"),
            parentId: try row.get("parentId")
        )
    }

    public func makeRow() throws -> Row {

        var row = Row()

        try row.set(Child.idKey, self.id)
        try row.set("name", self.name)
        try row.set("age", self.age)
        try row.set("parentId", self.parentId)

        return row
    }
}

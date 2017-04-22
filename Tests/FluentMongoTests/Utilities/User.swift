//
//  User.swift
//  FluentMongo
//
//  Created by Paul Rolfe on 9/10/16.
//
//

import Fluent

final class User: Entity {
    let storage = Storage()
    
    var id: Fluent.Node?
    var name: String?
    var email: String?
    var exists = false
    
    init(id: Node?, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
    
    init(row: Row) throws {
        id = try row["_id"]?.converted()
        name = try row["name"]?.converted()
        email = try row["email"]?.converted()
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set("_id", id)
        try row.set("name", name)
        try row.set("email", email)
        return row
    }
}

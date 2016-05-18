import Fluent
import MongoKitten

public class MongoDriver: Fluent.Driver {
    /**
        MongoDB uses `_id` as the main identifier.
    */
    public var idKey: String = "_id"

    /**
        Describes the types of errors
        this driver can throw.
    */
    public enum Error: ErrorProtocol {
        case unsupported(String)
    }
    
    var database: MongoKitten.Database

    /**
        Creates a new `MongoDriver` with
        the given database name, credentials, and port. 
    */
    public init(database: String, user: String, password: String, host: String, port: Int) throws {
        let server = try Server("mongodb://\(user):\(password)@\(host):\(port)", automatically: true)
        self.database = server[database]
    }
    
    /**
        Executes a query on the current MongoDB database.
    */
    public func execute<T: Model>(_ query: Fluent.Query<T>) throws -> [[String: Fluent.Value]] {
        var items: [[String: Fluent.Value]] = []

        print("Mongo executing: \(query)")

        switch query.action {
        case .fetch:
            let cursor = try select(query)
            for document in cursor {
                let item = convert(document: document)
                items.append(item)
            }
        case .create:
            let document = try insert(query)
            if let document = document {
                let item = convert(document: document)
                items.append(item)
            }
        case .delete:
            try delete(query)
        default:
            throw Error.unsupported("Action \(query.action) is not yet supported.")
        }

        return items
    }

    /**
        Provides a closure for executing raw, unsafe
        queries on the Mongo database.
    */
    public func raw(closure: (MongoKitten.Database) -> Document) -> Document {
        return closure(database)
    }

    //MARK: Private

    private func convert(document: Document) -> [String: Fluent.Value] {
        var item: [String: Fluent.Value] = [:]

        document.forEach { key, val in
            item[key] = val.structuredData
        }

        return item
    }

    private func delete<T: Model>(_ query: Fluent.Query<T>) throws {
        if let q = query.mongoKittenQuery {
            try database[query.entity].remove(matching: q)
        } else {
            try database[query.entity].drop()
        }
    }

    private func insert<T: Model>(_ query: Fluent.Query<T>) throws -> Document? {
        guard let data = query.data else {
            return nil
        }

        var document: Document = [:]

        for (key, val) in data {
            document[key] = val?.bson ?? .null
        }
        
        return try database[query.entity].insert(document)
    }

    private func select<T: Model>(_ query: Fluent.Query<T>) throws -> Cursor<Document> {
        let cursor: Cursor<Document>

        if let q = query.mongoKittenQuery {
            cursor = try database[query.entity].find(matching: q)
        } else {
            cursor = try database[query.entity].find()
        }

        return cursor
    }
}

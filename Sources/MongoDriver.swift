import Fluent
import MongoKitten

public class MongoDriver: Fluent.Driver {
    
    /**
        Describes the types of errors
        this driver can throw.
    */
    public enum Error: Swift.Error {
        case unsupported(String)
    }
    
    let database: MongoKitten.Database
    
    /**
        Creates a new `MongoDriver` with
        the given database name, credentials, and port.
    */
    public init(database: String, user: String, password: String, host: String, port: Int) throws {
        let server = try Server("mongodb://\(user):\(password)@\(host):\(port)", automatically: true)
        self.database = server[database]
    }
    
    // MARK: All the Driver protocol implementations

    /**
        MongoDB uses `_id` as the main identifier.
    */
    public var idKey: String = "_id"
    
    /**
        Executes a query on the current MongoDB database.
    */
    public func query<T : Entity>(_ query: Fluent.Query<T>) throws -> Node {
        print("Mongo executing: \(query)")
        
        switch query.action {
        case .fetch:
            let cursor = try select(query)
            var items: [Node] = []
            for document in cursor {
                let i = convert(document: document)
                items.append(i)
            }
            return try items.makeNode()
        case .create:
            let document = try insert(query)
            return convert(document: document)
        case .delete:
            try delete(query)
            return Node.null
        default:
            throw Error.unsupported("Action \(query.action) is not yet supported.")
        }
    }
    
    public func schema(_ schema: Schema) throws {
        // No schemas in Mongo
    }
    
    public func raw(_ raw: String, _ values: [Node]) throws -> Node {
        throw Error.unsupported("Mongo does not support raw queries.")
    }

    // MARK: Private

    private func convert(document: Document) -> Node {
        return document.makeBsonValue().node
    }

    private func delete<T: Entity>(_ query: Fluent.Query<T>) throws {
        if let q = query.mongoKittenQuery {
            try database[query.entity].remove(matching: q)
        } else {
            try database[query.entity].drop()
        }
    }

    private func insert<T: Entity>(_ query: Fluent.Query<T>) throws -> Document {
        guard let data = query.data?.nodeObject else {
            throw Error.unsupported("No data to insert")
        }
        var document: Document = [:]
        
        for (key, val) in data {
            document[key] = val.bson
        }
        
        return try database[query.entity].insert(document)
    }

    private func select<T: Entity>(_ query: Fluent.Query<T>) throws -> Cursor<Document> {
        let cursor: Cursor<Document>

        if let q = query.mongoKittenQuery {
            cursor = try database[query.entity].find(matching: q)
        } else {
            cursor = try database[query.entity].find()
        }

        return cursor
    }
}


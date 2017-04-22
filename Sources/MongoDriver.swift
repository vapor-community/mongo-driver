import Foundation
import Fluent
import MongoKitten

public class MongoDriver: Connection, Fluent.Driver{
    /// id keys, table names, etc.
    /// ex: snake_case vs. camelCase.
    public var keyNamingConvention: KeyNamingConvention = .snake_case
    public var log: QueryLogCallback?
    
    public /// The default type for values stored against the identifier key.
    ///
    /// The `idType` will be accessed by those Entity implementations
    /// which do not themselves implement `Entity.idType`.
    var idType: IdentifierType = .uuid
    
    /**
        Describes the types of errors
        this driver can throw.
    */
    public enum Error: Swift.Error {
        case noData
        case noQuery
        case unsupported(String)
    }
    
    public var isClosed: Bool = false
    
    public func makeConnection(_ type: ConnectionType) throws -> Connection {
        return self
    }
    
    let database: MongoKitten.Database

    /**
        Creates a new `MongoDriver` with
        the given database name, credentials, and port.
    */
    public init(database: String, user: String, password: String, host: String, port: Int) throws {
        guard let escapedUser = user.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
          throw Error.unsupported("Failed to percent encode username")
        }
        guard let escapedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
          throw Error.unsupported("Failed to percent encode password")
        }
        let server = try Server("mongodb://\(escapedUser):\(escapedPassword)@\(host):\(port)")
        self.database = server[database]
    }

    /**
        MongoDB uses `_id` as the main identifier.
    */
    public var idKey: String = "_id"
    
    /**
        Executes a query on the current MongoDB database.
    */
    public func query<T : Entity>(_ query: Fluent.Query<T>) throws -> Node {
        switch query.action {
        case .fetch:
            let cursor = try select(query)
            var items: [Node] = []
            for document in cursor {
                let i = convert(document: document)
                items.append(i)
            }
            return try items.makeNode(in: items.first?.context)
        case .create:
            let document = try insert(query)
            if let documentId = getId(document: document) {
                return documentId
            } else {
                throw MongoError.invalidResponse(documents: [document])
            }
        case .delete:
            try delete(query)
            return Node.null
        case .modify:
            try modify(query)
            return try query.raw()
        default:
            throw Error.unsupported("Action: \(query.action) is not supported.")
        }
    }
    
    public func schema(_ schema: Schema) throws {
        switch schema {
        case .delete:
            try database.drop()
        default:
            return
            // No schemas in Mongo to modify or create
        }
    }
    
    public func raw(_ raw: String, _ values: [Node]) throws -> Node {
        throw Error.unsupported("Mongo does not support raw queries.")
    }

    // MARK: Private
    
    private func convert(document: Document) -> Node {
        return document.node
    }

    private func getId(document: Document) -> Node? {
        return convert(document: document)[idKey]
    }

    private func delete<T: Entity>(_ query: Fluent.Query<T>) throws {
        switch (query.filters.count, query.limits.count ) {
        case (0, 0):
            try database[T.entity].drop()
        case (_, 0):
            // Limit 0: delete all matching documents
            let aqt = try query.makeAQT()
            let mkq = MKQuery(aqt: aqt)
            try database[T.entity].remove(mkq, limiting: 1, writeConcern: nil, stoppingOnError: true)
        case (_, 1):
            // Limit 1: delete first matching document
            let aqt = try query.makeAQT()
            let mkq = MKQuery(aqt: aqt)
            try database[T.entity].remove(mkq, limiting: 1, writeConcern: nil, stoppingOnError: true)
        case (_, _):
            throw Error.unsupported("Mongo only supports limit 0 (all documents) or limit 1 (single document) for deletes")
        }
    }

    private func insert<T: Entity>(_ query: Fluent.Query<T>) throws -> Document {

        let data = query.data
        var document: Document = [:]
        
        for (key, val) in data {
            if key.description == idKey && val.wrapped == Node.null {
                continue
            }
            document[key.description] = document.dictionaryValue
        }
        
        return try database[T.entity].insert(document) as! Document
    }

    private func select<T: Entity>(_ query: Fluent.Query<T>) throws -> CollectionSlice<Document> {
        let cursor: CollectionSlice<Document>

        let aqt = try query.makeAQT()
        let mkq = MKQuery(aqt: aqt)
        let sort: MongoKitten.Sort?
        let limit = Limit(count: query.limits.count, offset: 0)
    
        if !query.sorts.isEmpty {
            sort = query.sorts.flatMap { fluentSort in
                guard let fluentSort = fluentSort.wrapped else {
                    return nil
                }
                let direction: MongoKitten.SortOrder = fluentSort.direction == .ascending ? .ascending : .descending
                return [fluentSort.field : direction]
                }.reduce([:], +)
        } else {
            sort = nil
        }
        
        if query.limits.isEmpty {
            cursor = try database[T.entity].find(mkq, sortedBy: sort)

        }else {
            cursor = try database[T.entity].find(mkq,
                                                 sortedBy: sort,
                                                 skipping: limit.offset,
                                                 limitedTo: query.limits.count)
    }

        return cursor
    }

    private func modify<T: Entity>(_ query: Fluent.Query<T>) throws {
         let data = query.data

        let aqt = try query.makeAQT()
        let mkq = MKQuery(aqt: aqt)

        var document: Document = [:]

        for (key, val) in data {
            if key.description == idKey {
                continue
            }
            if let unwrappedVal = val.wrapped {
                document[key.description] = unwrappedVal.bson
            }
        }

        try database[T.entity].update(mkq, to: document, upserting: false, multiple: false, writeConcern: nil, stoppingOnError: true)
    }
}


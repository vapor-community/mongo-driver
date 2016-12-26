import Foundation
import Fluent
import MongoKitten

public class MongoDriver: Fluent.Driver {
    
    /**
        Describes the types of errors
        this driver can throw.
    */
    public enum Error: Swift.Error {
        case noData
        case noQuery
        case unsupported(String)
    }
    
    public let database: MongoKitten.Database
    
    /**
        Creates a new `MongoDriver` with
        the given database name, credentials, and port.
    */
    public init(connectionString: String) throws {
        self.database = try Database(mongoURL: connectionString)
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
            return try items.makeNode()
        case .create:
            return try insert(query).node
        case .delete:
            try delete(query)
            return Node.null
        case .modify:
            try modify(query)
            return query.data ?? Node.null
        }
    }
    
    public func schema(_ schema: Schema) throws {
        switch schema {
        case .delete(let entity):
            try database[entity].drop()
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
        switch (query.filters.count, query.limit?.count ?? 0) {
        case (0, 0):
            try database[query.entity].drop()
        case (_, 0):
            // Limit 0: delete all matching documents
            try database[query.entity].remove(matching: query.makeMKQuery())
        case (_, 1):
            // Limit 1: delete first matching document
            try database[query.entity].remove(matching: query.makeMKQuery(), limitedTo: 1, stoppingOnError: true)
        case (_, _):
            throw Error.unsupported("Mongo only supports limit 0 (all documents) or limit 1 (single document) for deletes")
        }
    }

    private func insert<T: Entity>(_ query: Fluent.Query<T>) throws -> ValueConvertible {
        guard let data = query.data?.nodeObject else {
            throw Error.noData
        }
        var document: Document = [:]
        
        for (key, val) in data {
            if key == idKey && val == .null {
                continue
            }
            document[raw: key] = val
        }
        
        return try database[query.entity].insert(document)
    }

    private func select<T: Entity>(_ query: Fluent.Query<T>) throws -> Cursor<Document> {
        let cursor: Cursor<Document>

        let mkq = try query.makeMKQuery()
        let sortDocument: MongoKitten.Sort?
        
        if !query.sorts.isEmpty {
            let elements = query.sorts.map { sort -> (String, ValueConvertible?) in
                (sort.field, sort.direction == .ascending ? SortOrder.ascending : SortOrder.descending)
            }
            sortDocument = MongoKitten.Sort(Document(dictionaryElements: elements))
        } else {
            sortDocument = nil
        }
        
        if let limit = query.limit {
            cursor = try database[query.entity].find(matching: mkq,
                                                     sortedBy: sortDocument,
                                                     skipping: Int32(limit.offset),
                                                     limitedTo: Int32(limit.count))
        } else {
            cursor = try database[query.entity].find(matching: mkq,
                                                     sortedBy: sortDocument)
        }
        
        return cursor
    }

    private func modify<T: Entity>(_ query: Fluent.Query<T>) throws {
        guard let data = query.data?.nodeObject else {
            throw Error.noData
        }
        
        var document: Document = [:]

        for (key, val) in data {
            if key == idKey {
                continue
            }
            document[raw: key] = val
        }

        try database[query.entity].update(matching: query.makeMKQuery(), to: document)
    }
}


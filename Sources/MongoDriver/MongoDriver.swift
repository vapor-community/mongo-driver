import Foundation
import Fluent
import MongoKitten

/// Conforms MongoKitten.Database as a Fluent.Driver and a Fluent.Connection.
///
/// This ensures MongoDB databases can be used for Fluent. Connections are handled by MongoKitten internally.
///
/// MongoKitten.Database can be initialized by it's original connection string and other initializers. This ensures that all new MongoKitten connection string features will also be supported.
extension MongoKitten.Database : Fluent.Driver, Connection {
    /// MongoDB's identifier is always in the `_id` field
    public var idKey: String {
        return "_id"
    }
    
    /// Generally, the identifier is ObjectId. It's a computed property since this is in an extension, currently ObjectId is the only supported type.
    ///
    /// TODO: Support other identifier types
    public var idType: IdentifierType {
        return .custom("ObjectId")
    }
    
    /// Fewer characters mean slightly faster indexes
    public var keyNamingConvention: KeyNamingConvention {
        return .camelCase
    }
    
    /// This is unsupported for now
    public var queryLogger: QueryLogger? {
        get {
            return nil
        }
        set {
            print("Query logging is unsupported")
        }
    }
    
    /// All FluentMongo Driver Errors
    public enum Error : Swift.Error {
        /// No query operation type has been provided
        case invalidQuery
        
        /// Invalid Node data has been provided by Fluent that cannot be transformed into a Document
        case invalidData
        
        /// A (currently) unsupported feature
        ///
        /// TODO: Never throw this error. When this isn't being thrown anymore we're good :)
        case unsupported
    }
    
    /// Connection is handled internally in MongoKitten
    public func makeConnection(_ type: ConnectionType) throws -> Connection {
        return self
    }
    
    /// The connection status is calculated by MongoKitten
    public var isClosed: Bool {
        return !server.isConnected
    }
    
    /// The query type
    private enum Method {
        case and, or
    }
    
    /// Creates a MongoKitten Query from an array of Fluent.Filter
    ///
    /// TODO: Support all MongoDB operations
    private func makeQuery(_ filters: [RawOr<Filter>], method: Method) throws -> MKQuery {

        var query = MKQuery()
        
        for filter in filters {
            guard let filter = filter.wrapped else {
                throw Error.unsupported
            }
            
            let subQuery: MKQuery

            switch filter.method {
            case .compare(let key, let comparison, let value):
                guard let value = value.makePrimitive() else {
                    throw Error.unsupported
                }
                
                switch (comparison, value) {
                case (.equals, _):
                    subQuery = key == value
                case (.greaterThan, _):
                    subQuery = key > value
                case (.greaterThanOrEquals, _):
                    subQuery = key >= value
                case (.lessThan, _):
                    subQuery = key < value
                case (.lessThanOrEquals, _):
                    subQuery = key <= value
                case (.notEquals, _):
                    subQuery = key != value
                case (.contains, let value as String):
                    subQuery = MKQuery(aqt: AQT.contains(key: key, val: value, options: []))
                case (.hasSuffix, let value as String):
                    subQuery = MKQuery(aqt: AQT.endsWith(key: key, val: value))
                case (.hasPrefix, let value as String):
                    subQuery = MKQuery(aqt: AQT.startsWith(key: key, val: value))
                case (.custom(_), _):
                    // TODO:
                    throw Error.unsupported
                default:
                    throw Error.unsupported
                }
            case .group(let relation, let filters):
                switch relation {
                case .and:
                    subQuery = try makeQuery(filters, method: .and)
                case .or:
                    subQuery = try makeQuery(filters, method: .or)
                }
            case .subset(let key, let scope, let values):
                switch scope {
                case .in:
                    subQuery = MKQuery(aqt: AQT.in(key: key, in: values))
                case .notIn:
                    subQuery = MKQuery(aqt: AQT.not(AQT.in(key: key, in: values)))
                }
            }

            if query.makeDocument().count == 0  {
                query = subQuery
            } else {
                switch method {
                case .and:
                    query = query && subQuery
                case .or:
                    query = query || subQuery
                }
            }
        }
        
        return query
    }
    
    /// Transforms Fluent.Sort into MongoKitten.Sort so that it can be passed to MongoKitten
    private func makeSort(_ sorts: [RawOr<Fluent.Sort>]) -> MKSort? {
        let sortSpec = sorts.flatMap {
            $0.wrapped
        }.map { sort -> MKSort in
            let direction = sort.direction == .ascending ? SortOrder.ascending : SortOrder.descending
            return [sort.field: direction] as MKSort
        }.reduce([:], +)
        
        if sortSpec.makeDocument().count > 0 {
            return sortSpec
        }
        
        return nil
    }
    
    /// Transforms [Fluent.Limit] into a Limit+Skip parameter for mutating operations
    private func makeLimits(_ limits: [RawOr<Limit>]) throws -> (limit: Int?, skip: Int?) {
        guard let limit = limits.first?.wrapped else {
            return (nil, nil)
        }
        
        guard limits.count == 1 else {
            throw Error.unsupported
        }
        
        return (limit.count, limit.offset)
    }
    
    /// Transforms Fluent Query data into a Document
    ///
    /// Used for Create/Update operations
    private func makeDocument(_ data: [RawOr<String>: RawOr<Node>]) throws -> Document {
        var document = Document()
        
        for (key, value) in data {
            guard let key = key.wrapped, let value = value.wrapped else {
                throw Error.invalidData
            }
            
            // Arrays need to be converted to documents first
            if let arrayValue = value.array {
                document[key] = Document(array: arrayValue)
            } else {
                document[key] = value
            }
            
        }
        
        if let key = document.type(at: "_id"), case ElementType.nullValue = key {
            document["_id"] = nil
        }
        
        return document
    }
    
    /// Exequtes a Fluent.Query for an Entity
    ///
    ///
    public func query<E>(_ query: RawOr<Fluent.Query<E>>) throws -> Node {

        guard let query = query.wrapped else {
            throw Error.invalidQuery
        }

        switch query.action {
        case .create:
            return try self.create(query)
        case .fetch:
            return try self.fetch(query)
        case .aggregate:
            return try self.aggregate(query)
        case .modify:
            return try self.modify(query)
        case .delete:
            return try self.delete(query)
        case .schema:
            return try self.schema(query)
        }
    }

    // MARK: Actions

    private func create<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard query.action == .create else {
            throw Error.invalidQuery
        }

        let collection = self[E.entity]
        let document = try makeDocument(query.data)

        return try collection.insert(document).makeNode()
    }

    private func fetch<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard case .fetch(let computedProperties) = query.action else {
            throw Error.invalidQuery
        }

        // TODO: Support ComputedProperties
        guard computedProperties.isEmpty else {
            throw Error.unsupported
        }

        let collection = self[E.entity]
        let filter = try makeQuery(query.filters, method: .and)
        let sort = makeSort(query.sorts)
        let (limit, skip) = try makeLimits(query.limits)

        if let lookup = query.joins.first?.wrapped {
            let results = try self[lookup.joined.entity].aggregate([
                .match(filter),
                .lookup(from: collection, localField: lookup.joinedKey, foreignField: lookup.baseKey, as: "_id"),
                .project(["_id"]),
                .unwind("$_id"),
                ])

            return Array(results.flatMap({ input in
                return Document(input["_id"])
            })).makeNode()
        }

        return Array(try collection.find(filter, sortedBy: sort, skipping: skip, limitedTo: limit)).makeNode()
    }

    private func aggregate<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard case .aggregate(let field, let action) = query.action else {
            throw Error.invalidQuery
        }

        guard action != .count else {
            return try self.count(query)
        }

        guard let someField = field else {
            throw Error.invalidQuery
        }

        let collection = self[E.entity]
        var effectiveCollection = collection
        let filter = try self.makeQuery(query.filters, method: .and)
        var pipeline: AggregationPipeline = [.match(filter)]

        if let lookup = query.joins.first?.wrapped {

            effectiveCollection = self[lookup.joined.entity]
            pipeline.append(.lookup(from: collection, localField: lookup.joinedKey, foreignField: lookup.baseKey, as: lookup.base.name))
            pipeline.append(.project(Projection(["_id": false]) + Projection([someField: "$" + lookup.base.name + "." + someField])))
            pipeline.append(.unwind("$" + someField))
        }

        switch action {
        case .average:
            pipeline.append(.group("null", computed: ["aggregated_value": .averageOf("$" + someField)]))
        case .sum:
            pipeline.append(.group("null", computed: ["aggregated_value": .sumOf("$" + someField)]))
        case .min:
            pipeline.append(.group("null", computed: ["aggregated_value": .minOf("$" + someField)]))
        case .max:
            pipeline.append(.group("null", computed: ["aggregated_value": .maxOf("$" + someField)]))
        default:
            throw Error.unsupported
        }

        let cursor = try effectiveCollection.aggregate(pipeline)

        return Array(cursor.flatMap({ input in
            return Int(input["aggregated_value"])
        })).first?.makeNode() ?? 0
    }

    private func count<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard case .aggregate(let field, .count) = query.action else {
            throw Error.invalidQuery
        }

        let collection = self[E.entity]
        var filter = try makeQuery(query.filters, method: .and)
        let (limit, skip) = try makeLimits(query.limits)

        // Counting is not necessarily an aggregation operation in MongoDB
        if let field = field {
            filter &= Query(aqt: .exists(key: field, exists: true))
        }

        // TODO: Support ComputedProperties
        if let lookup = query.joins.first?.wrapped {
            let results = try self[lookup.joined.entity].aggregate([
                .match(filter),
                .lookup(from: collection, localField: lookup.joinedKey, foreignField: lookup.baseKey, as: "_id"),
                .project(["_id"]),
                .unwind("$_id"),
                .count(insertedAtKey: "count")
                ])

            return Array(results.flatMap({ input in
                return Int(input["count"])
            })).first?.makeNode() ?? 0
        }

        return try collection.count(filter, limitedTo: limit, skipping: skip).makeNode()
    }

    private func modify<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard query.action == .modify else {
            throw Error.invalidQuery
        }

        let collection = self[E.entity]
        let filter = try self.makeQuery(query.filters, method: .and)
        let document = try makeDocument(query.data)

        return try collection.update(filter, to: ["$set": document], upserting: false, multiple: true).makeNode()
    }

    private func delete<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard query.action == .delete else {
            throw Error.invalidQuery
        }

        let collection = self[E.entity]
        let filter = try self.makeQuery(query.filters, method: .and)
        let limit = try makeLimits(query.limits).limit ?? 0

        return try collection.remove(filter, limitedTo: limit).makeNode()
    }

    private func schema<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard case .schema(let schema) = query.action else {
            throw Error.invalidQuery
        }

        switch schema {
        case .createIndex:
            print("Please create indexes for this through MongoKitten")

            return false
        case .deleteIndex:
            print("Please delete indexes for this through MongoKitten")

            return false
        case .create, .modify:
            // Schema's are managed by Fluent. MongoDB doesn't require a schema. No need to support this, for now.
            return true
        case .delete:
            try self[E.entity].drop()

            return true
        }
    }
}

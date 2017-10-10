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
                if relation == .and {
                    subQuery = try makeQuery(filters, method: .and)
                } else {
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
            } else if method == .and {
                query = query && subQuery
            } else {
                query = query || subQuery
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
    public func query<E>(_ query: RawOr<Fluent.Query<E>>) throws -> Node where E : Entity {
        guard let query = query.wrapped else {
            throw Error.invalidQuery
        }
        
        let collection = self[E.entity]
        var filter = try makeQuery(query.filters, method: .and)
        let document = try makeDocument(query.data)
        let sort = makeSort(query.sorts)
        let (limit, skip) = try makeLimits(query.limits)
        
        switch query.action {
        case .create:
            return try collection.insert(document).makeNode()
        case .fetch(let computedProperties):
            guard computedProperties.count == 0 else {
                throw Error.unsupported
            }
            
            // TODO: Support ComputedProperties
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
        // Aggregates aren't like an Aggregation Pipeline
        // They're like a query on all occurences of a field
        case .aggregate(let field, let aggregate):
            switch aggregate {
            case .count:
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
            case .sum:
                throw Error.unsupported
            case .average:
                throw Error.unsupported
            case .min:

                guard let field = field else {
                    throw Error.invalidQuery
                }

                let pipeline: AggregationPipeline = [
                    .match(filter),
                    .group("null", computed: ["min": .minOf("$" + field)])
                ]

                // TODO: Apply the same lookup logic that is in max

                let cursor = try collection.aggregate(pipeline)

                return Array(cursor.flatMap({ input in
                    return Int(input["min"])
                })).first?.makeNode() ?? 0

            case .max:

                guard let field = field else {
                    throw Error.invalidQuery
                }

                var pipeline: AggregationPipeline = [.match(filter)]

                var effectiveCollection = collection

                if let lookup = query.joins.first?.wrapped {

                    effectiveCollection = self[lookup.joined.entity]

                    pipeline.append(.lookup(from: collection, localField: lookup.joinedKey, foreignField: lookup.baseKey, as: "_id"))
                    pipeline.append(.project(["_id"]))
                    pipeline.append(.unwind("$_id"))
                }

                // Fluent always aggregate on a single field
                pipeline.append(.group("null", computed: ["max": .maxOf("$" + field)]))

                let cursor = try effectiveCollection.aggregate(pipeline)

                return Array(cursor.flatMap({ input in
                    return Int(input["max"])
                })).first?.makeNode() ?? 0

            case .custom(_):
                // TODO: Implement
                throw Error.unsupported
            }
        case .modify:
            return try collection.update(filter, to: ["$set": document], upserting: false, multiple: true).makeNode()
        case .delete:
            return try collection.remove(filter, limitedTo: limit ?? 0).makeNode()
        case .schema(let schema):
            switch schema {
            case .createIndex(_):
                print("Please create indexes this through MongoKitten")
                
                return false
            case .deleteIndex(_):
                print("Please delete indexes this through MongoKitten")
                
                return false
            case .create(_, _):
                // Schema's are managed by Fluent. MongoDB doesn't require a schema. No need to support this, for now.
                return true
            case .modify(_, _, _, _):
                // Same here. Schema's are managed by Fluent. MongoDB doesn't require a schema.
                return true
            case .delete:
                try collection.drop()
                
                return true
            }
        }
    }
}

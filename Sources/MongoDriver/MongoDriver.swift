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

            func eval(_ key: String) -> String {

                return filter.entity.name + "." + key
            }

            let subQuery: MKQuery

            switch filter.method {
            case .compare(var key, let comparison, let value):
                guard let value = value.makePrimitive() else {
                    throw Error.unsupported
                }

                key = eval(key)

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
                    subQuery = try self.makeQuery(filters, method: .and)
                case .or:
                    subQuery = try self.makeQuery(filters, method: .or)
                }
            case .subset(var key, let scope, let values):

                key = eval(key)

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
                    query &= subQuery
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
            return [sort.entity.name + "." + sort.field: direction] as MKSort
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

    private func makeAggregationPipeline<E>(_ query: Fluent.Query<E>) throws -> AggregationPipeline {

        let filter = try makeQuery(query.filters, method: .and)
        let sort = makeSort(query.sorts)
        let (limit, skip) = try makeLimits(query.limits)

        var projectionFields: [String: Projection.ProjectionExpression] = [:]

        if case .fetch(let computedProperties) = query.action, !computedProperties.isEmpty {
            var fields = try computedProperties.reduce(into: [String: BSON.Primitive?](), { result, property in
                switch property {
                case .raw(let value, _):
                    result[value] = "$$ROOT." + value
                case .some:
                    throw Error.unsupported
                }
            })
            fields["_id"] = "$$ROOT._id"
            projectionFields[E.name] = .custom(fields)
        } else {
            projectionFields[E.name] = "$$ROOT"
        }

        var pipeline: AggregationPipeline = [
            .project(Projection(Document(dictionaryElements: projectionFields.map { ($0.0, $0.1) }))),
            .addFields(["_id": "$" + E.name + "._id"])
        ]

        for join in query.joins {

            guard let lookup = join.wrapped else {
                continue
            }

            let collectionName = lookup.joined.name

            pipeline.append(.lookup(from: self[lookup.joined.entity], localField: lookup.baseKey, foreignField: lookup.joinedKey, as: collectionName))
            pipeline.append(.unwind("$" + collectionName, preserveNullAndEmptyArrays: lookup.kind == .outer))
        }

        pipeline.append(.match(filter))

        if let sort = sort {
            pipeline.append(.sort(sort))
        }

        if let skip = skip {
            pipeline.append(.skip(skip))
        }

        if let limit = limit {
            pipeline.append(.limit(limit))
        }

        return pipeline
    }

    private func fetch<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard case .fetch(let computedProperties) = query.action else {
            throw Error.invalidQuery
        }

        // TODO: Support ComputedProperties
        //guard computedProperties.isEmpty else {
        //    throw Error.unsupported
        //}

        let collection = self[E.entity]
        let pipeline = try makeAggregationPipeline(query)

        let cursor = try collection.aggregate(pipeline)

        let n = Array(cursor.flatMap({ input in
            return Document(input[E.name])
        })).makeNode()

        return n
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
        let namespacedField = "$" + E.name + "." + someField
        var pipeline = try makeAggregationPipeline(query)

        switch action {
        case .average:
            pipeline.append(.group("null", computed: ["aggregated_value": .averageOf(namespacedField)]))
        case .sum:
            pipeline.append(.group("null", computed: ["aggregated_value": .sumOf(namespacedField)]))
        case .min:
            pipeline.append(.group("null", computed: ["aggregated_value": .minOf(namespacedField)]))
        case .max:
            pipeline.append(.group("null", computed: ["aggregated_value": .maxOf(namespacedField)]))
        default:
            throw Error.unsupported
        }

        let cursor = try collection.aggregate(pipeline)

        return Array(cursor.flatMap({ input in
            return Int(input["aggregated_value"])
        })).first?.makeNode() ?? 0
    }

    private func count<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard case .aggregate(_, .count) = query.action else {
            throw Error.invalidQuery
        }

        let collection = self[E.entity]
        var pipeline = try makeAggregationPipeline(query)

        pipeline.append(.count(insertedAtKey: "count"))

        let cursor = try collection.aggregate(pipeline)

        return Array(cursor.flatMap({ input in
            return Int(input["count"])
        })).first?.makeNode() ?? 0
    }

    private func modify<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard query.action == .modify else {
            throw Error.invalidQuery
        }

        let collection = self[E.entity]
        let document = try self.makeDocument(query.data)
        var pipeline = try self.makeAggregationPipeline(query)
        pipeline.append(.project(["_id"]))

        let cursor = try collection.aggregate(pipeline)

        let filter = MKQuery(aqt: AQT.in(key: "_id", in: cursor.flatMap({ $0["_id"] })))

        return try collection.update(filter, to: ["$set": document], upserting: false, multiple: true).makeNode()
    }

    private func delete<E>(_ query: Fluent.Query<E>) throws -> Node {

        guard query.action == .delete else {
            throw Error.invalidQuery
        }

        let collection = self[E.entity]
        var pipeline = try self.makeAggregationPipeline(query)
        pipeline.append(.project(["_id"]))

        let cursor = try collection.aggregate(pipeline)

        let filter = MKQuery(aqt: AQT.in(key: "_id", in: cursor.flatMap({ $0["_id"] })))

        return try collection.remove(filter, limitedTo: 0).makeNode()
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

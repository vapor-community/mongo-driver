import Async
import TLS
import CodableKit
import Fluent
import MongoKitten

/// An error that gets thrown if the ConnectionRepresentable needs to represent itself but fails to do so because it is used in a different context
struct FluentMongoError: Error {
    enum Problem {
        case invalidConnectionType, invalidCreateQuery, searchInInvalidPrimitive, unsupported, implementationError
    }
    
    var problem: Problem
}

extension ObjectId: ID {
    public static var identifierType: IDType<ObjectId> {
        return .supplied
    }
}

extension QueryComparison {
    func apply(_ value: Primitive, to field: String, on query: inout Query) throws {
        switch self {
        case .equality(let comparison):
            switch comparison {
            case .equals:
                query &= field == value
            case .notEquals:
                query &= field != value
            }
        case .order(let order):
            switch order {
            case .greaterThan:
                query &= field > value
            case .greaterThanOrEquals:
                query &= field >= value
            case .lessThan:
                query &= field < value
            case .lessThanOrEquals:
                query &= field <= value
            }
        case .sequence(let sequence):
            guard let value = value as? String else {
                throw FluentMongoError(problem: .searchInInvalidPrimitive)
            }
            
            switch sequence {
            case .contains:
                query &= Query(aqt: AQT.contains(key: field, val: value, options: []))
            case .hasPrefix:
                query &= Query(aqt: AQT.startsWith(key: field, val: value))
            case .hasSuffix:
                query &= Query(aqt: AQT.endsWith(key: field, val: value))
            }
        }
    }
}

extension Array where Element == Encodable {
    func makePrimitives() throws -> [Primitive] {
        return try self.map { element in
            return try BSONEncoder().encodePrimitive(element)
        }
    }
}

extension Array where Element == QueryFilter {
    func makeQuery() throws -> Query {
        var query = Query()
        
        for filter in self {
            switch filter.method {
            case .compare(let field, let type, let value):
                switch value {
                case .field(_):
                    // TODO: Should be technically possible, but is complex
                    throw FluentMongoError(problem: .unsupported)
                case .value(let encodable):
                    let value = try BSONEncoder().encodePrimitive(encodable)
                    
                    try type.apply(value, to: field.name, on: &query)
                }
            case .group(let relation, let filters):
                switch relation {
                case .and:
                    try query = query && filters.makeQuery()
                case .or:
                    try query = query || filters.makeQuery()
                }
            case .subset(let field, let scope, let value):
                switch scope {
                case .in:
                    switch value {
                    case .array(let array):
                        try query &= Query(aqt: AQT.in(key: field.name, in: array.makePrimitives()))
                    case .subquery(_):
                        // FIXME: MK5
                        throw FluentMongoError(problem: .unsupported)
                    }
                case .notIn:
                    switch value {
                    case .array(let array):
                        try query &= !Query(aqt: AQT.in(key: field.name, in: array.makePrimitives()))
                    case .subquery(_):
                        // FIXME: MK5
                        throw FluentMongoError(problem: .unsupported)
                    }
                }
            }
        }
        
        return query
    }
}

extension Array where Element == QuerySort {
    func makeMKSort() -> MongoKitten.Sort {
        return self.map { sort in
            return [
                sort.field.name: sort.direction.makeMKOrder()
            ]
        }.reduce([:], +)
    }
}

extension QuerySortDirection {
    func makeMKOrder() -> MongoKitten.SortOrder {
        switch self {
        case .ascending:
            return .ascending
        case .descending:
            return .descending
        }
    }
}

extension MongoKitten.DatabaseConnection: Fluent.DatabaseConnection {
    public typealias Config = MongoKitten.ClientSettings
    
    public func execute<I, D>(query: DatabaseQuery, into stream: I) where I : InputStream, D : Decodable, D == I.Input {
        do {
            let collection = self[query.entity][query.entity]
            
            let mkQuery = try query.filters.makeQuery()
            
            func send<P: Primitive>(_ future: Future<P>) {
                future.map(to: D.self) { count in
                    return try BSONDecoder().decode(D.self, from: [
                        "fluentAggregate": count
                        ] as Document)
                    }.do { count in
                        stream.next(count)
                        stream.close()
                    }.catch { error in
                        stream.error(error)
                        stream.close()
                }
            }
            
            switch query.action {
            case .create, .update:
                guard let data = query.data else {
                    throw FluentMongoError(problem: .invalidCreateQuery)
                }
                
                var document = try BSONEncoder().encode(data)
                
                let id = document["_id"] ?? ObjectId()
                document["_id"] = id
                
                collection.upsert("_id" == id, to: document).transform(to: id).do { _ in
                    stream.close()
                }.catch { error in
                    stream.error(error)
                    stream.close()
                }
            case .read:
                if query.aggregates.count >= 1 {
                    let aggregate = query.aggregates[0]
                    
                    guard case .count = aggregate.method, query.aggregates.count == 1 else {
                        throw FluentMongoError(problem: .unsupported)
                    }
                    
                    let count: Future<Int>
                    
                    if let range = query.range {
                        if let upper = range.upper {
                            count = collection.count(mkQuery, in: range.lower..<upper)
                        } else {
                            count = collection.count(mkQuery, in: range.lower...)
                        }
                    } else {
                        count = collection.count(mkQuery)
                    }
                    
                    send(count)
                } else {
                    let cursor: Cursor
                    let sort = query.sorts.makeMKSort()
                    
                    if let range = query.range {
                        if let upper = range.upper {
                            cursor = collection.find(mkQuery, in: range.lower..<upper, sortedBy: sort)
                        } else {
                            cursor = collection.find(mkQuery, in: range.lower..., sortedBy: sort)
                        }
                    } else {
                        cursor = collection.find(mkQuery, sortedBy: sort)
                    }
                    
                    cursor.map(to: D.self) { doc in
                        return try BSONDecoder().decode(D.self, from: doc)
                    }.output(to: stream)
                }
            case .delete:
                let removed = collection.remove(mkQuery)
                
                send(removed)
            case .aggregate(_, _, _):
                fatalError()
            }
        } catch {
            stream.error(error)
        }
    }
    
    public var lastAutoincrementID: Int? {
        return nil
    }
    
    public func existingConnection<D>(to type: D.Type) -> D.Connection? where D : Fluent.Database {
        return self as? D.Connection
    }
    
    public func connect<D>(to database: DatabaseIdentifier<D>) -> Future<D.Connection> {
        guard D.self == MongoDB.self else {
            return Future(error: FluentMongoError(problem: .invalidConnectionType))
        }
        
        return Future(self[database.uid] as! D.Connection)
    }
}

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

///// A Fluent wrapper around a MySQL connection that can log
//public final class Mongo: DatabaseConnectable, JoinSupporting, ReferenceSupporting {
//    public typealias Config = FluentMySQLConfig
//
//    public func close() {
//        self.connection.close()
//    }
//
//    public func existingConnection<D>(to type: D.Type) -> D.Connection? where D : Database {
//        return self as? D.Connection
//    }
//
//    /// Respresents the current FluentMySQLConnection as a connection to `D`
//    public func connect<D>(to database: DatabaseIdentifier<D>) -> Future<D.Connection> {
//        fatalError("Call `.existingConnection` first.")
//    }
//
//    /// Keeps track of logs by MySQL
//    let logger: MySQLLogger?
//
//    /// The underlying MySQL Connection that can be used for normal queries
//    public let connection: MySQLConnection
//
//    /// Used to create a new FluentMySQLConnection wrapper
//    init(connection: MySQLConnection, logger: MySQLLogger?) {
//        self.connection = connection
//        self.logger = logger
//    }
//
//    /// See QueryExecutor.execute
//    public func execute<I, D: Decodable>(query: DatabaseQuery, into stream: I) where I : Async.InputStream, D == I.Input {
//        /// convert fluent query to an abstract SQL query
//        var (dataQuery, binds) = query.makeDataQuery()
//
//        if let model = query.data {
//            // Encode the model to read it's keys to be used inside the query
//            let encoder = CodingPathKeyPreEncoder()
//
//            do {
//                dataQuery.columns += try encoder.keys(for: model).flatMap { keys in
//                    guard let key = keys.first else {
//                        return nil
//                    }
//
//                    return DataColumn(name: key)
//                }
//            } catch {
//                // Close the stream with an error
//                stream.error(error)
//                stream.close()
//                return
//            }
//        }
//
//        /// Create a MySQL query string
//        let sqlString = MySQLSerializer().serialize(data: dataQuery)
//
//        _ = self.logger?.log(query: sqlString)
//
//        if query.data == nil && binds.count == 0 {
//            do {
//                try connection.stream(D.self, in: sqlString, to: stream)
//            } catch {
//                stream.error(error)
//                stream.close()
//            }
//            return
//        }
//
//        // Prepares the statement for binding
//        connection.withPreparation(statement: sqlString) { context -> Future<Void> in
//            do {
//                // Binds the model and other values
//                let bound = try context.bind { binding in
//                    try binding.withEncoder { encoder in
//                        if let model = query.data {
//                            try model.encode(to: encoder)
//                        }
//
//                        for bind in binds {
//                            try bind.encodable.encode(to: encoder)
//                        }
//                    }
//                }
//
//                // Streams all results into the parameter-provided stream
//                try bound.stream(D.self, in: sqlString, to: stream)
//                // try bound.stream(D.self, in: _, to: stream)
//
//                return Future<Void>(())
//            } catch {
//                // Close the stream with an error
//                stream.error(error)
//                stream.close()
//                return Future(error: error)
//            }
//            }.catch { error in
//                // Close the stream with an error
//                stream.error(error)
//                stream.close()
//        }
//    }
//
//    /// ReferenceSupporting.enableReferences
//    public func enableReferences() -> Future<Void> {
//        return connection.administrativeQuery("SET FOREIGN_KEY_CHECKS=1;")
//    }
//
//    /// ReferenceSupporting.disableReferences
//    public func disableReferences() -> Future<Void> {
//        return connection.administrativeQuery("SET FOREIGN_KEY_CHECKS=0;")
//    }
//
//    // FIXME: exposure from the MySQL driver
//    public var lastAutoincrementID: Int? {
//        if let id = connection.lastInsertID, id < numericCast(Int.max) {
//            return numericCast(id)
//        }
//
//        return nil
//    }
//}
//
//

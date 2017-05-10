import Foundation
import Fluent
import MongoKitten

extension MongoKitten.Database : Fluent.Driver, Connection {
    public var idKey: String {
        return "_id"
    }
    
    public var idType: IdentifierType {
        return .custom("ObjectId")
    }
    
    public var keyNamingConvention: KeyNamingConvention {
        return .camelCase
    }
    
    public var queryLogger: QueryLogger? {
        get {
            return nil
        }
        set {
            print("Query logging is unsupported")
        }
    }
    
    public enum Error : Swift.Error {
        case invalidQuery
        case invalidData
        case unsupported
    }
    
    public func makeConnection(_ type: ConnectionType) throws -> Connection {
        return self
    }
    
    public var isClosed: Bool {
        return !server.isConnected
    }
    
    private enum Method {
        case and, or
    }
    
    private func makeQuery(_ filters: [RawOr<Filter>], method: Method) throws -> MKQuery {
        var query = MKQuery()
        
        for filter in filters {
            guard let filter = filter.wrapped else {
                throw Error.unsupported
            }
            
            switch filter.method {
            case .compare(let key, let comparison, let value):
                guard let value = value.makePrimitive() else {
                    throw Error.unsupported
                }
                
                let subQuery: MKQuery
                
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
                case (.custom(let operation), _):
                    // TODO:
                    throw Error.unsupported
                default:
                    throw Error.unsupported
                }
                
                if method == .and {
                    query = query && subQuery
                } else {
                    query = query || subQuery
                }
            case .group(let relation, let filters):
                if relation == .and {
                    return try makeQuery(filters, method: .and)
                }
                
                return try makeQuery(filters, method: .or)
            case .subset(let key, let scope, let subValues):
                // TODO:
                throw Error.unsupported
            }
        }
        
        return query
    }
    
    private func makeProjection(_ keys: [RawOr<String>]) -> Projection? {
        let keys = keys.flatMap { $0.wrapped }.map { [$0] as Projection }
        
        if keys.count > 0 {
            return keys.reduce([], +)
        } else {
            return nil
        }
    }
    
    private func makeSort(_ sorts: [RawOr<Fluent.Sort>]) -> MKSort? {
        return sorts.flatMap {
            $0.wrapped
            }.map { sort in
                let direction = sort.direction == .ascending ? SortOrder.ascending : SortOrder.descending
                return [sort.field: direction] as MKSort
            }.reduce([:], +)
    }
    
    private func makeLimits(_ limits: [RawOr<Limit>]) throws -> (limit: Int?, skip: Int?) {
        guard let limit = limits.first?.wrapped else {
            return (nil, nil)
        }
        
        guard limits.count == 1 else {
            throw Error.unsupported
        }
        
        return (limit.count, limit.offset)
    }
    
    public func makeDocument(_ data: [RawOr<String>: RawOr<Node>]) throws -> Document {
        var document = Document()
        
        for (key, value) in data {
            guard let key = key.wrapped, let value = value.wrapped else {
                throw Error.invalidData
            }
            
            document[key] = value
        }
        
        if let key = document.type(at: "_id"), case ElementType.nullValue = key {
            document["_id"] = nil
        }
        
        return document
    }
    
    public func query<E>(_ query: RawOr<Fluent.Query<E>>) throws -> Node where E : Entity {
        guard let query = query.wrapped else {
            throw Error.invalidQuery
        }
        
        let collection = self[E.entity]
        let filter = try makeQuery(query.filters, method: .and)
        let document = try makeDocument(query.data)
        let sort = makeSort(query.sorts)
        let (limit, skip) = try makeLimits(query.limits)
        let projection = makeProjection(query.keys)
        
        let lookups = query.joins.flatMap { $0.wrapped }.map {
            AggregationPipeline.Stage.lookup(from: $0.joined.entity, localField: $0.baseKey, foreignField: $0.joinedKey, as: $0.baseKey)
        }
        
        let aggregationPipeline: AggregationPipeline?
        
        if lookups.count > 0 {
            var pipeline: AggregationPipeline = [
                .match(filter)
            ]
            
            if let limit = limit, let skip = skip {
                pipeline.append(.limit(limit))
                pipeline.append(.skip(skip))
            }
            
            for stage in lookups {
                pipeline.append(stage)
            }
            
            if let sort = sort {
                pipeline.append(.sort(sort))
            }
            
            if let projection = projection {
                pipeline.append(.project(projection))
            }
            
            aggregationPipeline = pipeline
        } else {
            aggregationPipeline = nil
        }
        
        switch query.action {
        case .create:
            return try collection.insert(document).makeNode()
        case .fetch:
            if let aggregationPipeline = aggregationPipeline {
                return Array(try collection.aggregate(aggregationPipeline)).makeNode()
            }
            
            return Array(try collection.find(filter, sortedBy: sort, projecting: projection, skipping: skip, limitedTo: limit)).makeNode()
        case .aggregate(let field, let aggregate):
            // TODO:
            
            switch aggregate {
            case .count:
                return try collection.count(filter, limiting: limit, skipping: skip).makeNode()
            case .sum:
                return false
            case .average:
                return false
            case .min:
                return false
            case .max:
                return false
            case .custom(_):
                return false
            }
        case .modify:
            return try collection.update(filter, to: ["$set": document], upserting: false, multiple: true).makeNode()
        case .delete:
            return try collection.remove(filter, limiting: limit ?? 1).makeNode()
        case .schema(let schema):
            switch schema {
            case .createIndex(_):
                print("Please create indexes this through MongoKitten")
                
                return false
            case .deleteIndex(_):
                print("Please delete indexes this through MongoKitten")
                
                return false
            case .create(_, _):
                return true
            case .modify(_, _, _, _):
                return true
            case .delete:
                try collection.drop()
                
                return true
            }
        }
    }
}

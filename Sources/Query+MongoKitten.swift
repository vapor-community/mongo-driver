import MongoKitten
import Fluent

extension Fluent.Query {
    func makeMKQuery() throws -> MongoKitten.Query {
        if unions.count != 0 {
            fatalError("[Mongo] Unions not yet supported. Use nesting instead.")
        }
        
        switch filters.count {
        case 0: return Query([:])
        case 1: return try filters[0].makeMKQuery()
        default:
            let queries = try filters.map {
                try $0.makeMKQuery()
            }
            return queries.dropFirst().reduce(queries[0], &&)
        }
    }
}

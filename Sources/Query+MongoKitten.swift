import MongoKitten
import Fluent

extension Fluent.Query {
    func makeMKQuery() throws -> MongoKitten.Query {
        if unions.count != 0 {
            fatalError("[Mongo] Unions not yet supported. Use nesting instead.")
        }

        let query = filters.map {
            $0.makeMKQuery()
        }.reduce(Query([:]), { lhs, rhs in
            return lhs && rhs
        })

        return query
    }
}

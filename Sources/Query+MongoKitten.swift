import MongoKitten
import Fluent

extension Fluent.Query {
    var mongoKittenQuery: MongoKitten.Query? {
        guard filters.count != 0 else {
            return nil
        }
        
        guard unions.count != 0 else {
            print("[Mongo] Unions not yet supported.")
        }
        
        var query: MongoKitten.Query?

        for filter in filters {
            let subquery = filter.mongoKittenFilter

            if let q = query {
                query = subquery && q
            } else {
                query = subquery
            }
        }

        return query
    }
}

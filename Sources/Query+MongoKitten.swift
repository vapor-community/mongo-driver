import MongoKitten
import Fluent

extension Fluent.Query {
    var mongoKittenQuery: AQTQuery? {
        guard filters.count != 0 else {
            return nil
        }

        var query: AQTQuery?

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

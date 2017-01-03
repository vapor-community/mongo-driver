import MongoKitten
import Fluent

extension Fluent.Filter {
    public func makeMKQuery() throws -> MongoKitten.Query {
        let query: MongoKitten.Query

        switch self.method {
        case .compare(let key, let comparison, let val):
            switch comparison {
            case .equals:
                if key == "_id", let id = try? ObjectId(val.string ?? "") {
                    query = "_id" == id
                } else {
                    query = key == val
                }
            case .greaterThan:
                query = key > val
            case .lessThan:
                query = key < val
            case .greaterThanOrEquals:
                query = key >= val
            case .lessThanOrEquals:
                query = key <= val
            case .notEquals:
                query = key != val
            case .contains:
                query = MKQuery(aqt: .contains(key: key, val: val.string ?? "", options: []))
            case .hasPrefix:
                query = MKQuery(aqt: .startsWith(key: key, val: val.string ?? ""))
            case .hasSuffix:
                query = MKQuery(aqt: .endsWith(key: key, val: val.string ?? ""))
            }
        case .subset(let key, let scope, let values):
            switch scope {
            case .in:
                var ors: [AQT] = []

                for val in values {
                    ors.append(.valEquals(key: key, val: val))
                }

                query = MKQuery(aqt: .or(ors))
            case .notIn:
                var ands: [AQT] = []

                for val in values {
                    ands.append(.valNotEquals(key: key, val: val))
                }

                query = MKQuery(aqt: .and(ands))
            }
        case .group(let relation, let filters):
            if filters.count >= 2 {
                let queries = try filters.map {
                    try $0.makeMKQuery()
                }
                switch relation {
                case .and: return queries.dropFirst().reduce(queries[0], &&)
                case .or: return queries.dropFirst().reduce(queries[0], ||)
                }
            } else {
                fatalError("Filter group must have at least 2 filters")
            }
        }
        
        return query
    }
}

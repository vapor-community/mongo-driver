import MongoKitten
import Fluent

extension Fluent.Filter {
    public func makeMKQuery() -> MongoKitten.Query {
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
            query = filters.map {
                $0.makeMKQuery()
                }.reduce(Query([:]), { lhs, rhs in
                    switch relation {
                    case .and: return lhs && rhs
                    case .or: return lhs || rhs
                    }
                })
        }
        
        return query
    }
}

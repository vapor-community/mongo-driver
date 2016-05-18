import MongoKitten
import Fluent

extension Fluent.Filter {
    var mongoKittenFilter: AQTQuery {
        let query: AQTQuery

        switch self {
        case .compare(let key, let comparison, let val):
            switch comparison {
            case .equals:
                query = AQTQuery(aqt: .valEquals(key: key, val: val.bson))
            case .greaterThan:
                query = AQTQuery(aqt: .greaterThan(key: key, val: val.bson))
            case .lessThan:
                query = AQTQuery(aqt: .smallerThan(key: key, val: val.bson))
            case .greaterThanOrEquals:
                query = AQTQuery(aqt: .greaterThanOrEqual(key: key, val: val.bson))
            case .lessThanOrEquals:
                query = AQTQuery(aqt: .smallerThanOrEqual(key: key, val: val.bson))
            case .notEquals:
                query = AQTQuery(aqt: .valNotEquals(key: key, val: val.bson))
            }
        case .subset(let key, let scope, let values):
            switch scope {
            case .in:
                var ors: [AQT] = []

                for val in values {
                    ors.append(.valEquals(key: key, val: val.bson))
                }

                query = AQTQuery(aqt: .or(ors))
            case .notIn:
                var ands: [AQT] = []

                for val in values {
                    ands.append(.valNotEquals(key: key, val: val.bson))
                }

                query = AQTQuery(aqt: .and(ands))
            }
        }

        return query
    }
}

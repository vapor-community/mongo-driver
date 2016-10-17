import MongoKitten
import Fluent

extension Fluent.Filter {
    var mongoKittenFilter: MongoKitten.Query {
        let query: MongoKitten.Query

        switch self.method {
        case .compare(let key, let comparison, let val):
            switch comparison {
            case .equals:
                if let objId = try? ObjectId(val.bson.string), key == "_id" {
                    let value = Value.objectId(objId)
                    query = MongoKitten.Query(aqt: .valEquals(key: key, val: value))
                } else {
                    query = MongoKitten.Query(aqt: .valEquals(key: key, val: val.bson))
                }
            case .greaterThan:
                query = MongoKitten.Query(aqt: .greaterThan(key: key, val: val.bson))
            case .lessThan:
                query = MongoKitten.Query(aqt: .smallerThan(key: key, val: val.bson))
            case .greaterThanOrEquals:
                query = MongoKitten.Query(aqt: .greaterThanOrEqual(key: key, val: val.bson))
            case .lessThanOrEquals:
                query = MongoKitten.Query(aqt: .smallerThanOrEqual(key: key, val: val.bson))
            case .notEquals:
                query = MongoKitten.Query(aqt: .valNotEquals(key: key, val: val.bson))
            case .contains:
                query = MongoKitten.Query(aqt: .contains(key: key, val: val.bson.string))
            case .hasPrefix:
                query = MongoKitten.Query(aqt: .startsWith(key: key, val: val.bson.string))
            case .hasSuffix:
                query = MongoKitten.Query(aqt: .endsWith(key: key, val: val.bson.string))
            }
        case .subset(let key, let scope, let values):
            switch scope {
            case .in:
                var ors: [AQT] = []

                for val in values {
                    ors.append(.valEquals(key: key, val: val.bson))
                }

                query = MongoKitten.Query(aqt: .or(ors))
            case .notIn:
                var ands: [AQT] = []

                for val in values {
                    ands.append(.valNotEquals(key: key, val: val.bson))
                }

                query = MongoKitten.Query(aqt: .and(ands))
            }
        case .group:
            print("[Mongo] Group filter method not yet supported.")
        }

        return query
    }
}

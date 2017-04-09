import MongoKitten
import Fluent

extension Fluent.Filter {
    public func makeAQT() throws -> MongoKitten.AQT {
        let query: MongoKitten.AQT
        var unwrappedValue: String = ""
        
        switch self.method {
        case .compare(let key, let comparison, let val):
            if let valString = val.string {
                unwrappedValue = valString
            }
  
            switch comparison {
            case .equals:
                if let objId = ObjectId(val.string), key == "_id" {
                    let value = objId
                    query = .valEquals(key: key, val: value)
                } else {
                    query = .valEquals(key: key, val: val.bson)
                }
            case .greaterThan:
                query = .greaterThan(key: key, val: val.bson)
            case .lessThan:
                query = .smallerThan(key: key, val: val.bson)
            case .greaterThanOrEquals:
                query = .greaterThanOrEqual(key: key, val: val.bson)
            case .lessThanOrEquals:
                query = .smallerThanOrEqual(key: key, val: val.bson)
            case .notEquals:
                query = .valNotEquals(key: key, val: val.bson)
            case .contains:
                query = .containsElement(key: key, match: val.bson as! AQT)
            case .hasPrefix:
                query = .startsWith(key: key, val: unwrappedValue)
            case .hasSuffix:
                query = .endsWith(key: key, val: unwrappedValue)
            case .custom(let comparison):
                query = .contains(key: comparison, val: unwrappedValue, options: .caseInsensitive)
            }
        case .subset(let key, let scope, let values):
            switch scope {
            case .in:
                var ors: [AQT] = []

                for val in values {
                    ors.append(.valEquals(key: key, val: val.bson))
                }

                query = .or(ors)
            case .notIn:
                var ands: [AQT] = []

                for val in values {
                    ands.append(.valNotEquals(key: key, val: val.bson))
                }

                query = .and(ands)
            }
        case .group(let relation, let filters):
            let aqts = try filters.map { try $0.wrapped?.makeAQT()}

            switch relation {
            case .and:
                query = .and(aqts as! [AQT])
            case .or:
                query = .or(aqts as! [AQT])
            }

        }
        return query
    }
}

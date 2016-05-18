import MongoKitten
import Fluent

extension StructuredData {
    var bson: BSON.Value {
        switch self {
        case .integer(let int):
            return .int64(Int64(int))
        case .array(let array):
            let bsonArray = array.map { item in
                return item.bson
            }
            let document = Document(array: bsonArray)
            return .array(document)
        case .bool(let bool):
            return .boolean(bool)
        case .dictionary(let dict):
            var bsonDict: Document = [:]
            dict.forEach { key, val in
                bsonDict[key] = val.bson
            }
            return .document(bsonDict)
        case .double(let double):
            return .double(double)
        case .null:
            return .null
        case .string(let string):
            return .string(string)
        }
    }
}

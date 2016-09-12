import MongoKitten
import Fluent
import Node

extension Node {
    var bson: BSON.Value {
        switch self {
        case .number(let num):
            switch num {
            case .int(let int):
                return .int64(Int64(int))
            case .double(let dbl):
                return .double(dbl)
            case .uint(let uint):
                return .int64(Int64(uint))
            }
        case .array(let array):
            let bsonArray = array.map { item in
                return item.bson
            }
            let document = Document(array: bsonArray)
            return .array(document)
        case .bool(let bool):
            return .boolean(bool)
        case .object(let dict):
            var bsonDict: Document = [:]
            dict.forEach { key, val in
                bsonDict[key] = val.bson
            }
            return .document(bsonDict)
        case .null:
            return .null
        case .string(let string):
            return .string(string)
        case .bytes(let byteArray):
            return .binary(subtype: .generic, data: byteArray)
        }
    }
}

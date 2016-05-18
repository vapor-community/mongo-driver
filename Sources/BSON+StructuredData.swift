import MongoKitten
import Fluent

extension BSON.Value {
    var structuredData: StructuredData {
        switch self {
        case .double(let double):
            return .double(double)
        case .int64(let int):
            return .integer(Int(int))
        case .string(let string):
            return .string(string)
        case .objectId(let objId):
            return .string(objId.hexString)
        case .null:
            return .null
        default:
            print("Unsupported type BSON.Value -> SD: \(self)")
            return .null
        }
    }
}

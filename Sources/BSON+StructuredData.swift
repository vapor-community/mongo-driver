import MongoKitten
import Fluent

extension BSON.Value {
    var node: Node {
        switch self {
        case .double(let double):
            return .number(.double(double))
        case .int32(let int):
            return .number(.int(Int(int)))
        case .int64(let int):
            return .number(.int(Int(int)))
        case .string(let string):
            return .string(string)
        case .objectId(let objId):
            return .string(objId.hexString)
        case .null:
            return .null
        case .array(let doc):
            var arrayOfNodes: [Node] = []
            for (_, val) in doc {
                arrayOfNodes.append(val.node)
            }
            return .array(arrayOfNodes)
        case .document(let doc):
            var dictOfNodes: [String : Node] = [:]
            for (key, val) in doc {
                dictOfNodes[key] = val.node
            }
            return .object(dictOfNodes)
        case .binary(_, let data):
            return .bytes(data)
        case .boolean(let bool): 
            return .bool(bool)
        default:
            print("[FluentMongo] Could not convert BSON to Node.")
            return .null
        }
    }
}

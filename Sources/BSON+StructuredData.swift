import MongoKitten
import Fluent

extension Primitive {
    var node: Node {
        switch self {
        case let double as Double:
            return Node(StructuredData.Number.double(double))
        case let int32 as Int:
            return Node(StructuredData.Number.int(int32))
        case let int64 as StructuredData.Number:
            return .number(int64)
        case let string as String:
            return .string(string)
        case let objId as ObjectId:
            return .string(objId.hexString)
        case let null as StructuredData.Number:
            return Node(null)
        case let doc as Document:
            let dictionary = doc
            var dictOfNodes: [String : Node] = [:]
            for (key, _) in doc {
                dictOfNodes[key] = dictionary.node
            }
            return .object(dictOfNodes)
        case let arrays as [Document]:
            let array = arrays
            var arrayOfNodes: [Node] = []
                arrayOfNodes.append(array.node)
            return .array(arrayOfNodes)
        case let data as Bytes:
            return .bytes(data)
        case let bool as Bool:
            return .bool(bool)
        default:
            print("[FluentMongo] Could not convert BSON to Node.")
            return .null
        }
    }
}

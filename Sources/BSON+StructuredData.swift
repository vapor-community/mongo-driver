import BSON
import MongoKitten
import Fluent

//extension BSON.Value {
//    var node: Node {
//        switch self {
//        case .double(let double):
//            return .number(.double(double))
//        case .int32(let int):
//            return .number(.int(Int(int)))
//        case .int64(let int):
//            return .number(.int(Int(int)))
//        case .string(let string):
//            return .string(string)
//        case .objectId(let objId):
//            return .string(objId.hexString)
//        case .null:
//            return .null
//        case .array(let doc):
//            var arrayOfNodes: [Node] = []
//            for (_, val) in doc {
//                arrayOfNodes.append(val.node)
//            }
//            return .array(arrayOfNodes)
//        case .document(let doc):
//            var dictOfNodes: [String : Node] = [:]
//            for (key, val) in doc {
//                dictOfNodes[key] = val.node
//            }
//            return .object(dictOfNodes)
//        case .binary(_, let data):
//            return .bytes(data)
//        case .boolean(let bool): 
//            return .bool(bool)
//        default:
//            print("[FluentMongo] Could not convert BSON to Node.")
//            return .null
//        }
//    }
//}

extension ValueConvertible {
    var node: Node {
        let value = self.makeBSONPrimitive()
        
        switch value {
        case is Double:
            return .number(.double(self as! Double))
        case is Int, is Int32, is Int64:
            return .number(.int(value.int!))
        case is String:
            return .string(value as! String)
        case is ObjectId:
            return .string((value as! ObjectId).hexString)
        case is Binary:
            return .bytes((value as! Binary).makeBytes())
        case is Document:
            let document = (value as! Document)

            if document.validatesAsArray() {
                return .array(document.arrayValue.map { $0.node })
            } else {
                var dictOfNodes: [String : Node] = [:]
                
                for (key, val) in document {
                    dictOfNodes[key] = val.node
                }
                
                return .object(dictOfNodes)
            }
        default:
            return .null
        }
    }
}

import BSON
import MongoKitten
import Fluent

public extension ValueConvertible {
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
        case is Bool:
            return .bool(value.boolValue!)
        default:
            return .null
        }
    }
}

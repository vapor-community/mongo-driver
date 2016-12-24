import MongoKitten
import Fluent
import Node

extension Node: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .number(let num):
            switch num {
            case .int(let int):
                return Int64(int)
            case .double(let double):
                return double
            case .uint(let uint):
                return Int64(uint)
            }
        case .array(let array):
            return Document(array: array)
        case .bool(let bool):
            return bool
        case .object(let dict):
            var document: Document = [:]

            for (key, value) in dict {
                document[raw: key] = value
            }
            
            return document
        case .null:
            return Null()
        case .string(let string):
            return string
        case .bytes(let data):
            return Binary(data: data, withSubtype: .generic)
        }
    }
}

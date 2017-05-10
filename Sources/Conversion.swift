import Foundation
import Fluent
import MongoKitten
import Cheetah

enum KittenContext : Context {
    case bson(type: String)
}

extension Primitive {
    public func makeNode() -> Node {
        switch self {
        case let string as String:
            return .string(string)
        case let int32 as Int32:
            return .number(.int(Int(int32)))
        case let int as Int:
            return .number(.int(int))
        case let double as Double:
            return .number(.double(double))
        case let bool as Bool:
            return .bool(bool)
        case let array as Array<Primitive>:
            return .array(array.map { $0.makeNode() })
        case let document as Document:
            if document.validatesAsArray() {
                return .array(document.arrayValue.map { $0.makeNode() })
            } else {
                let object = document.map({ [$0.0: $0.1.makeNode()] as [String: Node] }).reduce([:]) { lhs, rhs in
                    var lhs = lhs
                    
                    for (key, value) in rhs {
                        lhs[key] = value
                    }
                    
                    return lhs
                    } as [String: Node]
                
                return .object(object)
            }
        case let objectId as ObjectId:
            return objectId.makeNode(in: nil)
        case let regex as RegularExpression:
            return regex.makeNode(in: nil)
        case let date as Date:
            return .date(date)
        case let binary as Binary:
            return binary.makeNode(in: nil)
        case let date as Date:
            return .date(date)
        default:
            return .null
        }
    }
}

extension Binary : NodeConvertible {
    public func makeNode(in context: Context?) -> Node {
        return .bytes([UInt8](self.data))
    }
    
    public init(node: Node) throws {
        guard let bytes = node.bytes else {
            throw NodeError.unableToConvert(input: node, expectation: "\(Bytes.self)", path: [])
        }
        
        self = Binary(data: bytes, withSubtype: .generic)
    }
}

extension ObjectId : NodeConvertible {
    public func makeNode(in context: Context?) -> Node {
        return Node(.string(self.hexString), in: KittenContext.bson(type: "ObjectId"))
    }
    
    public init(node: Node) throws {
        guard case KittenContext.bson(let type) = node.context, type == "ObjectId" else {
            throw NodeError.unableToConvert(input: node, expectation: "\(ObjectId.self)", path: [])
        }
        
        guard let string = node.string, let objectId = try? ObjectId(string) else {
            throw NodeError.unableToConvert(input: node, expectation: "\(ObjectId.self)", path: [])
        }
        
        self = objectId
    }
}

extension RegularExpression : NodeConvertible {
    public func makeNode(in context: Context?) -> Node {
        return Node(.array([.string(self.pattern), .number(.uint(self.options.rawValue))]), in: KittenContext.bson(type: "RegularExpression"))
    }
    
    public init(node: Node) throws {
        guard case KittenContext.bson(let type) = node.context, type == "RegularExpression" else {
            throw NodeError.unableToConvert(input: node, expectation: "\(RegularExpression.self)", path: [])
        }
        
        guard let array = node.array, array.count == 2, let pattern = array[0].string, let options = array[1].uint else {
            throw NodeError.unableToConvert(input: node, expectation: "\(RegularExpression.self)", path: [])
        }
        
        self = RegularExpression(pattern: pattern, options: NSRegularExpression.Options(rawValue: options))
    }
}

extension Node : Primitive {
    public func makePrimitive() -> Primitive? {
        guard case KittenContext.bson(let type) = self.context else {
            return self.wrapped.convert(to: BSONData.self)
        }
        
        switch type {
        case "ObjectId":
            return try? ObjectId(node: self).makeBinary()
        case "RegularExpression":
            return try? RegularExpression(node: self)
        default:
            return self.wrapped.convert(to: BSONData.self)
        }
    }
    
    public func makeBinary() -> Bytes {
        return (makePrimitive() ?? self.wrapped).makeBinary()
    }
    
    public func convert<DT>(to type: DT.Type) -> DT.SupportedValue? where DT : DataType {
        return (makePrimitive() ?? self.wrapped).convert(to: DT.self)
    }
    
    public var typeIdentifier: Byte {
        return (makePrimitive() ?? self.wrapped).typeIdentifier
    }
}

extension StructuredData : Convertible {
    public func convert<DT : DataType>(to type: DT.Type) -> DT.SupportedValue? {
        switch self {
        case .null:
            return Null().convert(to: type)
        case .bool(let value):
            return value.convert(to: type)
        case .number(let number):
            switch number {
            case .double(let double):
                return double.convert(to: type)
            case .int(let int):
                return int.convert(to: type)
            case .uint(let uint):
                return uint.convert(to: type)
            }
        case .string(let string):
            return string.convert(to: type)
        case .array(let array):
            return array.convert(to: type)
        case .object(let object):
            return object.convert(to: type)
        case .bytes(let bytes):
            return Data(bytes: bytes).convert(to: type)
        case .date(let date):
            return date.convert(to: type)
        }
    }
}

extension StructuredData : Primitive {
    public func makeBinary() -> Bytes {
        switch self {
        case .null:
            return Null().makeBinary()
        case .bool(let value):
            return value.makeBinary()
        case .number(let number):
            switch number {
            case .double(let double):
                return double.makeBinary()
            case .int(let int):
                return int.makeBinary()
            case .uint(let uint):
                return uint.convert(to: BSONData.self)?.makeBinary() ?? Int(uint).makeBinary()
            }
        case .string(let string):
            return string.makeBinary()
        case .array(let array):
            return Document(array: array).makeBinary()
        case .object(let object):
            return Document(dictionaryElements: object.map { pair in
                return (pair.key, pair.value)
            }).makeBinary()
        case .bytes(let bytes):
            return Binary(data: bytes, withSubtype: .generic).makeBinary()
        case .date(let date):
            return date.makeBinary()
        }
    }
    
    public var typeIdentifier: Byte {
        switch self {
        case .null:
            return 0x0A
        case .bool(_):
            return 0x08
        case .number(let number):
            switch number {
            case .double(_):
                return 0x01
            case .int(_):
                return 0x12
            case .uint(let uint):
                return uint.convert(to: BSONData.self)?.typeIdentifier ?? 0x12
            }
        case .string(_):
            return 0x02
        case .array(_):
            return 0x04
        case .object(_):
            return 0x03
        case .bytes(_):
            return 0x05
        case .date(_):
            return 0x09
        }
    }
}

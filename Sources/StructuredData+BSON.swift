import MongoKitten
import Fluent
import Node

extension Node {

    var bson: Primitive {
        switch wrapped {
        case .number (let num):
            switch num {
            case .int (let int):
                return StructuredData.Number(Int64(int)) as! Primitive
            case .double(let dbl):
                return StructuredData.Number(Double(dbl)) as! Primitive
            case .uint(let uint):
                return StructuredData.Number(Int64(uint)) as! Primitive
            }
        case .array(let array):
            let bsonArray = array.map { item in
                return item.makeNode(in: nil).bson
            }
            let document = Document(array: bsonArray)
            return document.array
        case .bool(let bool):
            return Bool(bool)
        case .object(let dict):
            var bsonDict: Document = [:]
            dict.forEach { key, val in
                bsonDict[key] = val.makeNode(in: nil).bson
            }
            return bsonDict
        case .null:
            return Null()
        case .string(let string):
            return String(string)
        case .bytes(let byteArray):
            return Binary.init(data: byteArray, withSubtype: .generic)
        case .date(let date):
            return Date(date)!
        }
    }
}

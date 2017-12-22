import BSON
import CodableKit

extension ObjectId: KeyStringDecodable {
    public static var keyStringTrue: ObjectId {
        return _trueID
    }
    
    public static var keyStringFalse: ObjectId {
        return _falseID
    }
}

fileprivate let _trueID = ObjectId()
fileprivate let _falseID = ObjectId()

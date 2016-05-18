import MongoKitten
import Fluent

extension Fluent.Value {
    var bson: BSON.Value {
        return structuredData.bson
    }
}

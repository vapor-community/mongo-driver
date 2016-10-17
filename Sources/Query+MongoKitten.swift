import MongoKitten
import Fluent

extension Fluent.Query {
    func makeAQT() throws -> MongoKitten.AQT {
        if unions.count != 0 {
            fatalError("[Mongo] Unions not yet supported. Use nesting instead.")
        }

        let aqts = try filters.map { try $0.makeAQT() }

        if aqts.isEmpty {
            return .nothing
        }

        return .and(aqts)
    }
}

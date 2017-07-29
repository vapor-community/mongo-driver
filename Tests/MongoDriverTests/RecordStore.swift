import Foundation
import Fluent

public final class RecordStore: Entity {
    
    public static let idType: IdentifierType = .uuid
    public let storage = Storage()
    public var vinyls: [Vinyl] = []
    
    enum Keys: String {
        case
            vinyls
    }
    
    public func makeRow() throws -> Row {
        
        var row = Row()
        try row.set(Keys.vinyls.rawValue, vinyls.flatMap { try $0.makeNode(in: nil) })
        
        return row
    }
    
    public init(vinyls: [Vinyl]) {
        self.vinyls = vinyls
    }
    
    public init(row: Row) throws {
        
        let vinylNode: Node? = try? row.get(Keys.vinyls.rawValue)
        
        vinyls = vinylNode?.array?.flatMap { node -> Vinyl? in
            
            guard
                let name = node[Vinyl.Keys.name.rawValue]?.string,
                let year = node[Vinyl.Keys.year.rawValue]?.int else {
                    return nil
            }
            
            return Vinyl(name: name, year: year)
            
        } ?? []
        
    }
    
}

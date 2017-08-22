import Foundation
import Fluent

public final class Vinyl: NodeRepresentable {
    
    public var name: String
    public var year: Int
    
    enum Keys: String {
        case
            name,
            year
    }
    
    public init(name: String, year: Int) {
        
        self.name = name
        self.year = year
        
    }
    
    public func makeNode(in context: Context?) throws -> Node {
        
        return Node.object(
            [
                Keys.name.rawValue: name.makeNode(),
                Keys.year.rawValue: year.makeNode()
            ]
        )
    }
    
}

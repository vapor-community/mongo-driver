import Foundation
import Fluent

public final class Vinyl: NodeRepresentable {

    public var authors: [String]
    public var name: String
    public var year: Int
    
    enum Keys: String {
        case
            authors,
            name,
            year
    }
    
    public init(authors: [String] = [], name: String, year: Int) {

        self.authors = authors
        self.name = name
        self.year = year
        
    }
    
    public func makeNode(in context: Context?) throws -> Node {
        
        return Node.object(
            [
                Keys.authors.rawValue: authors.makeNode(),
                Keys.name.rawValue: name.makeNode(),
                Keys.year.rawValue: year.makeNode()
            ]
        )
    }
    
}

import Foundation
import Fluent

final class NodeEntity: Entity {

    public var node: Node

    public init(node: Node) {
        self.node = node
    }

    // MARK: Storable

    public let storage = Storage()

    // MARK: RowConvertible

    public convenience init(row: Row) throws {
        self.init(node: row.makeNode(in: nil))
    }

    public func makeRow() throws -> Row {
        return Row(node: self.node)
    }
}

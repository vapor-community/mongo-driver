import Foundation
import Fluent

final class NodeEntity: Entity {

    public static var entity: String {
        return "nodeEntities"
    }

    public static var name: String {
        return "nodeEntity"
    }

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

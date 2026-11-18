import SwiftSyntax

public struct Violation: Sendable, Hashable {
    public var position: AbsolutePosition
    public var message: String
    public var notes: [Note]

    public init(position: AbsolutePosition, message: String, notes: [Note] = []) {
        self.position = position
        self.message = message
        self.notes = notes
    }

    public init(at node: some SyntaxProtocol, message: String, notes: [Note] = []) {
        self.init(position: node.positionAfterSkippingLeadingTrivia, message: message, notes: notes)
    }
}

public struct Note: Sendable, Hashable {
    public var position: AbsolutePosition
    public var message: String

    public init(position: AbsolutePosition, message: String) {
        self.position = position
        self.message = message
    }

    public init(at node: some SyntaxProtocol, message: String) {
        self.init(position: node.positionAfterSkippingLeadingTrivia, message: message)
    }
}

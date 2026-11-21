public struct Example: Sendable, Hashable {
    public static let markerNames = ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"]

    public let source: String
    public let options: String?
    public let files: [String: String]

    public init(_ source: String, options: String? = nil, files: [String: String] = [:]) {
        self.source = source
        self.options = options
        self.files = files
    }

    public func parse() -> ParsedExample {
        var cleanSource = ""
        var markers: [Marker] = []
        var utf8Offset = 0
        for character in source {
            let text = String(character)
            if Self.markerNames.contains(text) {
                markers.append(Marker(name: text, utf8Offset: utf8Offset))
            } else {
                cleanSource.append(character)
                utf8Offset += text.utf8.count
            }
        }
        return ParsedExample(source: cleanSource, markers: markers)
    }
}

public struct ParsedExample: Sendable, Hashable {
    public let source: String
    public let markers: [Marker]

    public init(source: String, markers: [Marker]) {
        self.source = source
        self.markers = markers
    }
}

public struct Marker: Sendable, Hashable {
    public let name: String
    public let utf8Offset: Int

    public init(name: String, utf8Offset: Int) {
        self.name = name
        self.utf8Offset = utf8Offset
    }
}

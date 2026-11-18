import Foundation
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

enum Console {
    static var isTerminal: Bool {
        isatty(STDOUT_FILENO) != 0
    }

    static func error(_ message: String) {
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    }

    static func output(_ text: String) {
        guard !text.isEmpty else { return }
        print(text)
    }
}

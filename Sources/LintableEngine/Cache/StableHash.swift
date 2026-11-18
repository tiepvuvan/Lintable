public enum StableHash {
    public static func hex(of text: String) -> String {
        hex(of: Array(text.utf8))
    }

    public static func hex(of bytes: some Sequence<UInt8>) -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        var length: UInt64 = 0
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
            length &+= 1
        }
        let hashText = String(hash, radix: 16)
        let lengthText = String(length, radix: 16)
        return String(repeating: "0", count: 16 - hashText.count) + hashText + "-" + lengthText
    }
}

import Foundation

/// Shared encoder for CLI JSON output.
enum JSONOutput {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static func printJSON<T: Encodable>(_ value: T) {
        guard let data = try? encoder.encode(value),
              let str = String(data: data, encoding: .utf8) else { return }
        Swift.print(str)
    }

    static func printJSONArray<T: Encodable>(_ items: [T]) {
        guard let data = try? encoder.encode(items),
              let str = String(data: data, encoding: .utf8) else { return }
        Swift.print(str)
    }
}

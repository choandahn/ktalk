import Foundation

/// Parses a duration string into a TimeInterval (seconds).
/// Supported formats: 250ms, 1s, 2m, 1h, 7d
public enum DurationParser {
    public static func parse(_ str: String) -> TimeInterval? {
        let trimmed = str.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }

        // Handle "ms" suffix
        if trimmed.hasSuffix("ms") {
            let numStr = String(trimmed.dropLast(2))
            guard let num = Double(numStr) else { return nil }
            return num / 1000.0
        }

        guard let last = trimmed.last, last.isLetter else { return nil }
        let numStr = String(trimmed.dropLast())
        guard let num = Double(numStr) else { return nil }

        switch last {
        case "s": return num
        case "m": return num * 60
        case "h": return num * 3600
        case "d": return num * 86400
        case "w": return num * 604800
        default: return nil
        }
    }
}

import Foundation

func resolvedProfileImageURL(from rawValue: String) -> URL? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let normalized: String
    if trimmed.hasPrefix("//") {
        normalized = "https:\(trimmed)"
    } else if trimmed.lowercased().hasPrefix("http://") {
        normalized = "https://\(trimmed.dropFirst("http://".count))"
    } else if trimmed.lowercased().hasPrefix("https://") {
        normalized = trimmed
    } else {
        normalized = "https://\(trimmed)"
    }

    if let parsed = URL(string: normalized), parsed.scheme != nil {
        return parsed
    }

    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:/?#[]@!$&'()*+,;=%")
    guard let encoded = normalized.addingPercentEncoding(withAllowedCharacters: allowed) else {
        return nil
    }

    return URL(string: encoded)
}

enum TimeFormatter {
    static func secondsString(from seconds: Double) -> String {
        String(normalizedSeconds(from: seconds))
    }

    static func minuteSecondText(from seconds: Double) -> String {
        let safeSeconds = normalizedSeconds(from: seconds)
        let minutes = safeSeconds / 60
        let remainingSeconds = safeSeconds % 60
        let secondText = remainingSeconds < 10 ? "0\(remainingSeconds)" : "\(remainingSeconds)"
        return "\(minutes):\(secondText)"
    }

    private static func normalizedSeconds(from seconds: Double) -> Int {
        max(Int(seconds.rounded(.down)), 0)
    }
}

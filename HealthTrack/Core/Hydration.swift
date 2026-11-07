import Foundation

enum Hydration {
    static let quickAddML = [250, 500, 750]
    /// The "other amount" dropdown.
    static let otherAmountsML = [100, 150, 200, 300, 330, 400, 600, 800, 1000, 1250, 1500]
    static let validRangeML = 1...5000
    /// A second identical tap this soon after the first is treated as an accidental double-tap.
    static let duplicateTapInterval: TimeInterval = 1.5

    static func isDuplicateTap(previousML: Int?, previousAt: Date?, amountML: Int, at: Date) -> Bool {
        guard let previousML, let previousAt else { return false }
        return previousML == amountML && abs(at.timeIntervalSince(previousAt)) < duplicateTapInterval
    }

    /// "1.9 / 2.5 L"
    static func progressText(totalML: Int, targetML: Int) -> String {
        String(format: "%.1f / %.1f L", Double(totalML) / 1000, Double(targetML) / 1000)
    }
}

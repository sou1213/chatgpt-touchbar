import Foundation

public enum SurvivalMeter {
    /// Twenty half-slots. Round down so the artwork never overstates capacity.
    public static func halfSlots(remainingPercent: Double) -> Int {
        guard remainingPercent.isFinite else { return 0 }
        return Int(floor(min(100, max(0, remainingPercent)) / 5))
    }
}

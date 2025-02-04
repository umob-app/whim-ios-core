import Foundation

/// Returns current value withing specified bounds.
///
/// If `min` is greater than `max`, will return current value.
/// - `42.inRange(min: 0, max: 40)` => `40`.
/// - `42.inRange(min: 40, max: 0)` => `42`.
extension Comparable {
    func inRange(min minValue: Self, max maxValue: Self) -> Self {
        guard minValue <= maxValue else { return self }
        return min(max(self, minValue), maxValue)
    }
}

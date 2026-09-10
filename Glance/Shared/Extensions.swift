import Foundation

extension Date {
    var millisecondsSinceEpoch: Int64 {
        Int64(timeIntervalSince1970 * 1_000)
    }
}

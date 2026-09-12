import Foundation
import UIKit

extension Date {
    var millisecondsSinceEpoch: Int64 {
        Int64(timeIntervalSince1970 * 1_000)
    }
}

extension UIApplication {
    var appIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primary["CFBundleIconFiles"] as? [String],
              let last = iconFiles.last else { return nil }
        return UIImage(named: last)
    }
}

import MousePortalCore
import SwiftUI

extension PortalColor {
    var swiftUIColor: Color {
        switch self {
        case .blue: Color(red: 0.19, green: 0.49, blue: 0.92)
        case .purple: Color(red: 0.56, green: 0.35, blue: 0.86)
        case .orange: Color(red: 0.94, green: 0.46, blue: 0.16)
        case .green: Color(red: 0.19, green: 0.65, blue: 0.37)
        case .pink: Color(red: 0.88, green: 0.31, blue: 0.55)
        case .teal: Color(red: 0.10, green: 0.63, blue: 0.67)
        }
    }
}

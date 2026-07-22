import SwiftUI

extension ElementCategory {
    var symbolName: String {
        switch self {
        case .view: "camera.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .facility: "cross.case.fill"
        }
    }

    var tint: Color {
        switch self {
        case .view: .purple
        case .caution: .orange
        case .facility: .blue
        }
    }
}

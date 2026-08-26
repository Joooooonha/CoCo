import SwiftUI

extension ElementCategory {
    /// Each symbol names what the place *is*, not what you would do there.
    /// The previous camera read as "take a photo here" and the medical case
    /// read as first aid, which is not what 편의 covers.
    var symbolName: String {
        switch self {
        // A viewpoint is somewhere you look from.
        case .view: "binoculars.fill"
        case .caution: "exclamationmark.triangle.fill"
        // What ties a toilet, a water fountain and a bench together is that
        // you stop there. A seated figure reads as that, and it pairs with
        // the running figure on the start marker.
        case .facility: "figure.seated.side"
        }
    }

    /// Orange belongs to caution and nothing else in this app, so the one
    /// category that means "be careful" is the one that stands out.
    var tint: Color {
        switch self {
        case .view: .teal
        case .caution: .orange
        case .facility: .indigo
        }
    }
}

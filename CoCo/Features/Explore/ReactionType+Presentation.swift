import SwiftUI

extension ReactionType {
    var symbolName: String {
        switch self {
        case .like: "hand.thumbsup"
        case .hard: "flame"
        case .scenic: "mountain.2"
        }
    }

    var filledSymbolName: String {
        switch self {
        case .like: "hand.thumbsup.fill"
        case .hard: "flame.fill"
        case .scenic: "mountain.2.fill"
        }
    }
}

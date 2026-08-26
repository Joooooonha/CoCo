import SwiftUI

/// Marks routes that were not produced by walking-route calculation.
///
/// A freehand line never touched the road network, so other runners are told
/// where it came from rather than being left to assume it was verified.
struct RouteSourceBadge: View {
    let routeSource: RouteSource

    var body: some View {
        if let label = routeSource.badgeLabel {
            Text(label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tint.opacity(0.18), in: Capsule())
                // Tinted caption text measures below 4.5:1 even with Increase
                // Contrast, so the chip carries the color and the word keeps a
                // label color that meets it.
                .foregroundStyle(.primary)
                .accessibilityLabel("경로 출처: \(label)")
        }
    }

    private var tint: Color {
        switch routeSource {
        case .drawnFreehand: .orange
        case .importedGPX: .blue
        case .plannedMapKit, .recordedGPS, .plannedKakao: .secondary
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        RouteSourceBadge(routeSource: .drawnFreehand)
        RouteSourceBadge(routeSource: .importedGPX)
        RouteSourceBadge(routeSource: .plannedMapKit)
    }
    .padding()
}

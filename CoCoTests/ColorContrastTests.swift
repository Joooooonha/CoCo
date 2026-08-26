import SwiftUI
import Testing
import UIKit

@testable import CoCo

/// Measures the contrast the system actually resolves, rather than trusting
/// published color values. Runs in the simulator so the traits are real.
///
/// HIG accessibility: text under 17pt needs 4.5:1, and non-text UI needs 3:1.
/// System colors are allowed to fall short by default as long as they meet the
/// bar once Increase Contrast is on, so both states are measured here.
struct ColorContrastTests {
    private struct Measurement {
        let name: String
        let normal: Double
        let increased: Double
    }

    /// The tint is used on glyphs and chip fills, never as caption text: as
    /// text it measured 3.83–4.38:1 with Increase Contrast on, short of the
    /// 4.5:1 that small text needs. As a non-text glyph the bar is 3:1.
    @Test
    func categoryTintsMeetContrastOnceIncreaseContrastIsOn() {
        let background = UIColor.systemGroupedBackground
        let results = ElementCategory.allCases.map { category in
            measure(
                name: category.displayName,
                foreground: UIColor(category.tint),
                background: background,
                style: .light
            )
        }

        for result in results {
            #expect(
                result.increased >= 3.0,
                "\(result.name): Increase Contrast에서도 \(String(format: "%.2f", result.increased)):1"
            )
        }
    }

    /// White glyphs sit on the tint inside map markers, so the pair has to work
    /// as a non-text component.
    @Test
    func markerGlyphsMeetContrastAgainstTheirFill() {
        for category in ElementCategory.allCases {
            let result = measure(
                name: category.displayName,
                foreground: .white,
                background: UIColor(category.tint),
                style: .light
            )

            #expect(
                result.increased >= 3.0,
                "\(result.name) 마커: Increase Contrast에서도 \(String(format: "%.2f", result.increased)):1"
            )
        }
    }

    @Test
    func categoryTintsAlsoWorkInDarkMode() {
        let background = UIColor.systemGroupedBackground

        for category in ElementCategory.allCases {
            let result = measure(
                name: category.displayName,
                foreground: UIColor(category.tint),
                background: background,
                style: .dark
            )

            #expect(
                result.increased >= 3.0,
                "\(result.name) 다크: Increase Contrast에서도 \(String(format: "%.2f", result.increased)):1"
            )
        }
    }

    // MARK: - Measurement

    private func measure(
        name: String,
        foreground: UIColor,
        background: UIColor,
        style: UIUserInterfaceStyle
    ) -> Measurement {
        let normal = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: style),
            UITraitCollection(accessibilityContrast: .normal)
        ])
        let increased = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: style),
            UITraitCollection(accessibilityContrast: .high)
        ])

        return Measurement(
            name: name,
            normal: ratio(
                foreground.resolvedColor(with: normal),
                background.resolvedColor(with: normal)
            ),
            increased: ratio(
                foreground.resolvedColor(with: increased),
                background.resolvedColor(with: increased)
            )
        )
    }

    private func ratio(_ a: UIColor, _ b: UIColor) -> Double {
        let first = relativeLuminance(a)
        let second = relativeLuminance(b)
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }
}

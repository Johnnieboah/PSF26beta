import SwiftUI
// MARK: - Environment Keys
private struct FormattedSalaryKey: EnvironmentKey {
    static let defaultValue: String = "$0"
}

extension EnvironmentValues {
    var formattedSalary: String {
        get { self[FormattedSalaryKey.self] }
        set { self[FormattedSalaryKey.self] = newValue }
    }
}

private struct FormattedOverallKey: EnvironmentKey {
    static let defaultValue: String = "OVR: 0"
}

extension EnvironmentValues {
    var formattedOverall: String {
        get { self[FormattedOverallKey.self] }
        set { self[FormattedOverallKey.self] = newValue }
    }
}

private struct FormattedPositionLineKey: EnvironmentKey {
    static let defaultValue: String = "POS • #0"
}

extension EnvironmentValues {
    var formattedPositionLine: String {
        get { self[FormattedPositionLineKey.self] }
        set { self[FormattedPositionLineKey.self] = newValue }
    }
}

// MARK: - Currency Utility
@inline(__always)
func formatCurrency(_ value: Int) -> String {
    // Fast simple formatter to avoid NumberFormatter overhead during scrolling
    if value >= 1_000_000 {
        let millions = Double(value) / 1_000_000.0
        // Players: show two decimals in millions (e.g., "$1.25 Million")
        return String(format: "$%.2f Million", millions)
    } else if value >= 1_000 {
        let thousands = Double(value) / 1_000.0
        return String(format: "$%.0fk", thousands)
    } else {
        return "$\(value)"
    }
}

// MARK: - iOS 26 Design System: Corner Tokens & Helpers

/// Centralized corner radius tokens to harmonize curvature across the app.
/// Matches iOS 26 hardware-informed rounded geometry using continuous corners.
public enum Corner {
    /// Large surfaces/cards, close to the device curvature
    public static let xLarge: CGFloat = 18
    /// Primary cards/panels
    public static let large: CGFloat = 16
    /// Secondary cards and list rows
    public static let medium: CGFloat = 12
    /// Chips/inline widgets
    public static let small: CGFloat = 8
    /// Tiny badges
    public static let xSmall: CGFloat = 4
}

// MARK: - View Helpers (Continuous Corners)

public extension View {
    /// Applies a Material background with continuous rounded corners.
    func roundedBackground(_ material: Material, radius: CGFloat) -> some View {
        background(material, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Applies a Color background with continuous rounded corners.
    func roundedBackground(_ color: Color, radius: CGFloat) -> some View {
        background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Clips the view using a continuous rounded rectangle.
    func continuousClip(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Uses the parent container’s shape when available to inherit curvature.
    /// Falls back to a continuous rounded rectangle if necessary.
    @ViewBuilder
    func containerRelativeRoundedBackground(_ material: Material, fallbackRadius: CGFloat = Corner.large) -> some View {
        if #available(iOS 16.0, *) { // ContainerRelativeShape arrived earlier; safe for iOS 16+
            background(material, in: ContainerRelativeShape())
        } else {
            background(material, in: RoundedRectangle(cornerRadius: fallbackRadius, style: .continuous))
        }
    }
}


